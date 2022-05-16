
# See CoreORM.utils.part2.jl for implementation
function util_get_column_type end
function util_is_column_numeric end

# TODO: There's probably a more efficient way than this to retrieve the db name
#         from the LibPQ.Connection
function util_getdbname(dbconn::LibPQ.Connection)
    filter(x -> x.keyword == "dbname",LibPQ.conninfo(dbconn))[1].val
end

function util_getdbhost(dbconn::LibPQ.Connection)
    host = filter(x -> x.keyword == "host",LibPQ.conninfo(dbconn))[1].val
    if ismissing(host)
        host = "localhost"
    end
    return host
end

function util_overwrite_props!(src::T,
                               target::T,
                               ignore_missing_props::Bool) where T <: IEntity
    for psymbol in propertynames(src)
        srcvalue = getproperty(src,psymbol)
        # If the src value is missing and we ignore the missing props we continue
        if (ismissing(srcvalue) && ignore_missing_props)
            continue
        end
        setproperty!(target,psymbol,srcvalue)
    end
end

"""
    util_get_entity_props_for_db_actions(entity::IEntity,
                                         dbconn::LibPQ.Connection,
                                         include_missing::Bool
                                        ;exclude_props::Union{Missing,Vector{Symbol}} = missing)::Dict

Returns a 'flat' dictionary of property names (and column names for the properties
that are IEntity) and values
"""
function util_get_entity_props_for_db_actions(entity::IEntity,
                                              dbconn::LibPQ.Connection,
                                              include_missing::Bool
                                             ;exclude_props::Union{Missing,Vector{Symbol}} = missing)::Dict


    entity_type = typeof(entity)
    orm_module = PostgresORM.get_orm(entity)
    columns_selection_and_mapping = util_get_columns_selection_and_mapping(orm_module)

    props = PostgresORMUtil.getproperties_asdict(entity, include_missing)

    # Exclude the props that are specified in optional argument
    if !ismissing(exclude_props)
        filter!(x -> !(x.first in exclude_props),props)
    end

    # Exclude the non map properties
    props = util_remove_unmapped_properties_from_dict(props,
                                                      columns_selection_and_mapping)

    # Tweak the dictionary of property values by:
    # - replacing the complex types by the IDS (may also replace the property name
    #     the column IDs if the complex type has a composite PK, hence composite FK)
    # - replacing the enums by their IDs
    # - replacing the Dict by a JSON string
    #
    # CAUTION: This functions does not replace all the property names by the
    #            columns names, only for the complex props
    props = util_replace_complex_types_by_id(props,
                                             columns_selection_and_mapping,
                                             entity_type)
    props = util_replace_enums_by_id_if_needed(props, orm_module, dbconn)
    props = util_replace_empty_vector_of_enums_by_missing(props)
    props = util_replace_dict_types(props, orm_module, dbconn)

end

"""
    util_get_entity_props_for_comparison(entity::IEntity,
                                         dbconn::LibPQ.Connection,
                                         include_missing)::Dict

Returns a 'flat' dictionary of property names (and column names for the properties
that are IEntity) and values so that we can compare the values with another
instance of the same type
"""
function util_get_entity_props_for_comparison(entity::IEntity,
                                              dbconn::LibPQ.Connection,
                                              ;drop_trackchanges_properties = true,
                                               drop_unmapped_properties = true)::Dict

    entity_type = typeof(entity)
    orm_module = PostgresORM.get_orm(entity)
    columns_selection_and_mapping = util_get_columns_selection_and_mapping(orm_module)

    props = PostgresORMUtil.getproperties_asdict(entity,
                                              true # include_missing IMPORTANT!!
                                              )

    if drop_unmapped_properties
        props =
           util_remove_unmapped_properties_from_dict(props,
                                                     columns_selection_and_mapping)
    end

    if drop_trackchanges_properties
        props =
            util_remove_trackchanges_properties_from_dict(props, orm_module)
    end

    # Tweak the dictionary of property values
    props = util_replace_complex_types_by_id(props,
                                             columns_selection_and_mapping,
                                             entity_type)
    props = util_replace_enums_by_id_if_needed(props,orm_module,dbconn)
    props = util_replace_empty_vector_of_enums_by_missing(props)
    props = util_replace_dict_types(props,orm_module,dbconn)

    return(props)

end

"""
    util_get_cols_names_and_values(entity::IEntity,
                                   dbconn::LibPQ.Connection)

Transform an entity in a dict with the key being the column name and the value
being the column value
"""
function util_get_cols_names_and_values(entity::IEntity,
                                        dbconn::LibPQ.Connection)

   props_db_actions = util_get_entity_props_for_db_actions(entity,
                                                           dbconn,
                                                           true, # include_missing
                                                           )

   orm_module = get_orm(entity)
   columns_selection_and_mapping = util_get_columns_selection_and_mapping(orm_module)

   props_names = collect(keys(props_db_actions))
   col_names = util_getcolumns(props_names, columns_selection_and_mapping)
   col_values = collect(values(props_db_actions))

   result = Dict{String,Any}()
   for (k,v) in zip(col_names,col_values)
       result[k] = v
   end

   return result

end

"""
    util_get_ids_cols_names_and_values(entity::IEntity)

Transform an entity in a dict with the keys being the ids names and the values
being the ids column values
"""
function util_get_ids_cols_names_and_values(entity::IEntity,
                                            dbconn::LibPQ.Connection)

   cols_names_and_values = util_get_cols_names_and_values(entity,
                                                          dbconn)
   ids_cols_names = util_get_ids_cols_names(entity)

   return filter(x -> x.first in ids_cols_names, cols_names_and_values)
end


function util_diff_entities(previous_state::IEntity, new_state::IEntity,
                            dbconn::LibPQ.Connection,
                            ;drop_trackchanges_properties = true,
                             drop_unmapped_properties = true)::Dict

    previous_state_props =
        util_get_entity_props_for_comparison(previous_state, dbconn
                                             ;drop_trackchanges_properties = drop_trackchanges_properties,
                                             drop_unmapped_properties = drop_unmapped_properties)

    new_state_props =
        util_get_entity_props_for_comparison(new_state,dbconn
                                            ;drop_trackchanges_properties = drop_trackchanges_properties,
                                             drop_unmapped_properties = drop_unmapped_properties)

    props_modified = diff_dict(previous_state_props, new_state_props)

    props_modified
end

function util_clean_and_rename_query_result(data::DataFrame,
                                            mapping::Dict)::DataFrame

    # Clean the mapping from the properties for which we don't have the columns
    #    in the dataframe
    # WARNING: DO NOT USE filter! because that would overwrite 'columns_selection_and_mapping'
    #          in the orm module
    mapping = filter(x -> begin
            cols = PostgresORMUtil.tovector(x.second)
            if all(y -> y in string.(names(data)),cols)
                return true
            else
                return false
            end
            # x.second in string.(names(data))
        end
     ,mapping)

    # Prepare the 2 vectors of properties and columns names
    datamodel_props = Symbol.(collect(keys(mapping)))
    database_cols = Vector{Symbol}()

    for v in collect(values(mapping))
        push!(database_cols,Symbol.(tovector(v))...)
    end

    # Remove duplicates (same columns can be referenced by several properties))
    database_cols = unique(database_cols)

     # Symbol.(collect(values(mapping)))

    # Clean the dataframe from the columns for which we don't have a property
    #    in the mapping
    data = data[:,database_cols]

    # Rename the selected columns
    # rename!(data, f => t for (f, t) = enumerate(mapping)) # does not work
    # rename!(data, f => t for (f, t) = zip(database_cols,
    #                                       datamodel_props))

    # for (f, t) in zip(database_cols,datamodel_props)
    #     rename!(data,f => t)
    # end

    return(data)

end

function util_getcolumns(propertiesnames::Vector,
                         columns_selection_and_mapping::Dict{Symbol,<:Any})

    column_names = String[]

    # NOTE: The mapping may not have the properties because some of the
    #          properties are the columns names of the complex objects
    #          which are added at runtime
    for p in propertiesnames
        if haskey(columns_selection_and_mapping,p)
            push!(column_names,tovector(columns_selection_and_mapping[p])...)
        else
            push!(column_names,string(p))
        end
    end
    column_names

end

function util_id2entity(ptype::DataType,
                        id_values::Vector,
                        load_props_from_db::Bool,
                        load_complex_properties::Bool,
                        dbconn::Union{LibPQ.Connection,Missing})

    # If one of the id values is missing, return missing
    # NOTE: We need to be strict on this and not allow some missing values
    #         because this would cause side effects (eg. when loading the
    #         complex props after a retrieve_entity)
    if any(map(x -> ismissing(x),id_values))
        return missing
    end

    complex_prop = ptype()
    id_properties = util_get_ids_props_names(complex_prop)

    # Check that the ID values that are expected to be IEntity are actually
    #   IEntity, convert them if not
    # @info "util_id2entity for DataType[$ptype] id_properties[$id_properties], id_values[$id_values] "
    for (idx, pair_prop_name_value) in enumerate(zip(id_properties, id_values))
        id_prop_name = pair_prop_name_value[1]
        id_prop_value = pair_prop_name_value[2]
        id_prop_type = util_get_property_real_type(ptype, Symbol(id_prop_name))
        if (id_prop_type <: IEntity && !isa(id_prop_value, IEntity))
            id_values[idx] = util_id2entity(id_prop_type,
                                            tovector(id_prop_value),
                                            false, # load_props_from_db::Bool,
                                            false, #load_complex_properties::Bool,
                                            dbconn)
        end
    end

    # If we retrieve the details of the object we set the
    #   ID property of a filter object and we retrieve the object
    if load_props_from_db
        # Prepare the filter object with the ID property set
        filter_object = ptype()
        # Set the ID property
        PostgresORMUtil.setpropertiesvalues!(filter_object,
                                               id_properties,
                                               id_values)

        queryresult = retrieve_entity(
            filter_object,
            PostgresORM.get_orm(filter_object),
            load_complex_properties,
            dbconn)
        if length(queryresult) == 0
            @warn "Unable to find an entry in database for DataType[$ptype] with ID[$id_values] => return missing."
            return missing
        end
        complex_prop = queryresult[1]

    # If we don't want to retrieve the details of the object we just
    #   create an object and we set it's ID property
    else
        PostgresORMUtil.setpropertiesvalues!(complex_prop,
                                               id_properties,
                                               id_values)
    end # if load_properties_from_db

    return complex_prop

end

function util_dict2entity(props_dict::Dict{Symbol,T},
                          object_type::DataType,
                          building_from_database_result::Bool,
                          retrieve_complex_props::Bool,
                          dbconn::Union{LibPQ.Connection,Missing}) where T <: Any

  # Clone the Dict to make sure that it is of type Dict{Symbol, Any} so that we
  #   can for example replace a value by another one of different type
  props_dict = Dict{Symbol,Any}(props_dict)

  # Drop the entries that do not correspond to a known property
  keys_to_drop = filter(x -> !(x in fieldnames(object_type)),
                        keys(props_dict))
  for k in keys_to_drop
    delete!(props_dict,k)
  end

  # @info props_dict

  # To make it simple, this function only go get some additional information in
  #   the DB if it's handling the result of a query. In other words, when we
  #   create an entity from a dictionnary not originating from a database result
  #   we won't use more information than the one contained in the dictionary.
  if !building_from_database_result
      retrieve_complex_props = false
      dbconn = missing
  end

  # Loop over the properties of the struct and get the values from the dictionary
  for fsymbol in fieldnames(object_type)

      # Get the 'non-missing' type of the property
      ftype = fieldtype(object_type,fsymbol)
      if (typeof(ftype) == Union)
          ftype = get_nonmissing_typeof_uniontype(ftype);
      end

      # Some attributes of the type may not be present
      if !haskey(props_dict,fsymbol)
          continue
      end

      # If attribute is already of the right type do nothing
      if isa(props_dict[fsymbol],ftype)
          continue

      # Override some properties
      elseif ftype <: UUID
          if ismissing(props_dict[fsymbol])
              continue
          end
          props_dict[fsymbol] = UUID(props_dict[fsymbol])

      elseif ftype <: DateTime
          if (ismissing(props_dict[fsymbol]))
              continue
          end
          # "2019-07-24T00:41:49.732Z" becomes "2019-07-24T00:41:49.732"
          date_match =
            match(r"^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3})",
                  props_dict[fsymbol])
          props_dict[fsymbol] = DateTime(date_match.match)

      elseif ftype <: ZonedDateTime
          if (ismissing(props_dict[fsymbol]))
              continue
          end
          zdt = string2zoneddatetime(props_dict[fsymbol])
          if isnothing(zdt)
              throw(
                DomainError("Cannot convert string[$(props_dict[fsymbol])] to $ftype for object "
                          * " of type[$object_type]. Please check 'string2zoneddatetime' "))
          else
              props_dict[fsymbol] = zdt
          end

      elseif ftype <: Date
          if (ismissing(props_dict[fsymbol]))
              continue
          end
          # "2019-07-24T00:41:49.732Z" becomes "2019-07-24"
          date_match =
            match(r"^([0-9]{4}-[0-9]{2}-[0-9]{2})",
                  props_dict[fsymbol])
          props_dict[fsymbol] = Date(date_match.match)

      elseif ftype <: Time
          if (ismissing(props_dict[fsymbol]))
              continue
          end
          # "2019-07-24T00:41:49.732Z" becomes "00:41:49"
          time_match =
            match(r"([0-9]{2}:[0-9]{2}:[0-9]{2})",
                  props_dict[fsymbol])
          props_dict[fsymbol] = Time(time_match.match)

      elseif ftype <: Vector{String}
          if (ismissing(props_dict[fsymbol]))
              continue
          end
          # @info props_dict[fsymbol]
          props_dict[fsymbol] =
            PostgresORMUtil.postgresql_string_array_2_string_vector(props_dict[fsymbol])

      elseif ftype <: Vector{T} where T <: Base.Enums.Enum

          # Treat the case where we can an empty vector, no matter the type (eg. Any[])
          if props_dict[fsymbol] isa Vector && isempty(props_dict[fsymbol])
              props_dict[fsymbol] = Vector{T}()
          elseif isa(props_dict[fsymbol],Union{Vector{T},Vector{Union{T,Missing}}} where T <: Integer)
              props_dict[fsymbol] = vector_of_integers2vector_of_enums(ftype,props_dict[fsymbol])
          elseif isa(props_dict[fsymbol],Union{Vector{String},Vector{Union{String,Missing}}})
                props_dict[fsymbol] = vector_of_strings2vector_of_enums(ftype,props_dict[fsymbol])
          else
              props_dict[fsymbol] = string2vector_of_enums(ftype,props_dict[fsymbol])
          end

      elseif ftype <: Enum

          if ismissing(props_dict[fsymbol])
              continue
          end

          # Convert the int or the string to the correct enum instance
          if isa(props_dict[fsymbol],Number)
              props_dict[fsymbol] = int2enum(ftype,
                                             convert(Int,props_dict[fsymbol]))
          else
              props_dict[fsymbol] = string2enum(ftype,
                                                props_dict[fsymbol])
          end
      # If the property is a Dict, we assume that it is serialized as a JSON
      #   string in the database
      elseif ftype <: Dict
          if (ismissing(props_dict[fsymbol]))
              continue
          end
          props_dict[fsymbol] = JSON.parse(props_dict[fsymbol])
      elseif ftype <: IEntity

          # Create an empty instance so that we can access the ORM of the type
          dummy_object = object_type()

          # If the property value is set, either create the
          #   instance with the ID property only or with all the properties
          #   that we rerieve in the database
          if !ismissing(props_dict[fsymbol])

              ptype = util_get_property_real_type(object_type, fsymbol)

              # Check that the ptype is compatible
              if !(ptype <: ftype)
                  throw(DomainError("Cannot convert $ptype to $ftype for object "
                                  * " of type[$object_type]. Please check 'types_override' "
                                  * " in the ORM[$(PostgresORM.get_orm(dummy_object))]"))
              end

              # Retrieve the ID property names of the complex property
              complex_prop_idprops = util_get_ids_props_names(ptype())

              # If building from the result of a query we convert the id to an entity
              if building_from_database_result
                  load_props_from_db = retrieve_complex_props

                  complex_prop = util_id2entity(ptype,
                                                getdictvalues(props_dict[fsymbol],complex_prop_idprops),
                                                # [props_dict[fsymbol]], # id_value::Any,
                                                load_props_from_db, # load_props_from_db
                                                false, # load_complex_properties
                                                dbconn)
              else
                  # If we are building from a dictionnary
                  if isa(props_dict[fsymbol],Dict)
                      complex_prop =
                        util_dict2entity(props_dict[fsymbol], # this is a dictionary
                                         ptype,
                                         building_from_database_result,
                                         retrieve_complex_props,
                                         dbconn)
                  else
                      load_props_from_db = retrieve_complex_props
                      # TODO: properly handle the case of composed foreign key
                      complex_prop =
                          util_id2entity(ptype,
                                         getdictvalues(props_dict[fsymbol],complex_prop_idprops),
                                         # [props_dict[fsymbol]], # id_value::Any,
                                         load_props_from_db, # load_props_from_db
                                         false, # load_complex_properties
                                         dbconn)
                  end
              end


              # Update the properties dictionary with the complex object
              props_dict[fsymbol] = complex_prop

          end # if !ismissing(props_dict[fsymbol])

      # This will handle the case of Vectors and Arrays of IEntity.
      elseif eltype(ftype) <: IEntity

          # Create an empty instance so that we can access the ORM of the type
          dummy_object = object_type()

          # This should only happen when dealing with results that are not
          #   coming from a query result. In which case the input should be a
          #   vector of Dict.
          if !ismissing(props_dict[fsymbol])

              # Check if there is a type override, if not we use the type found
              #  in the struct
              ptype = util_get_property_real_type(object_type, fsymbol)

              # Check that the ptype is compatible
              if !(eltype(ptype) <: eltype(ftype))
                  throw(DomainError("Cannot convert $ptype to $ftype for object "
                                  * " of type[$object_type]. Please check 'types_override' "
                                  * " in the ORM[$(PostgresORM.get_orm(dummy_object))]"))
              end

              # Check that the elements type is not abstract
              if isabstracttype(eltype(ptype))
                  throw(DomainError("Cannot instantiate type[$ptype] of property[:$fsymbol] because it's a vector of abstract elements. "
                                  * " Please set a non-abstract vector in 'types_override'"
                                  * " in the ORM[$(PostgresORM.get_orm(dummy_object))]"))
              end

              # Instantiate a new array/vector of the given type
              complex_vector_prop = ptype()

              # For every dictionary in the vector we create an entity and add
              #   it to the vector
              for dct in props_dict[fsymbol]
                  push!(complex_vector_prop,
                        util_dict2entity(dct, # this is a dictionary
                                         eltype(ptype),
                                         building_from_database_result,
                                         retrieve_complex_props,
                                         dbconn)
                  )
              end



              # Update the properties dictionary with the complex object
              props_dict[fsymbol] = complex_vector_prop

          end # if !ismissing(props_dict[fsymbol])
      end # eltype(ftype) <: IEntity

  end # for fsymbol in fieldnames(object_type)

  obj = object_type(dict2namedtuple(props_dict))
  return(obj)
end

function util_get_property_real_type(datatype::DataType, propname::Symbol)

    dummy_object = datatype()
    orm_module = get_orm(dummy_object)

    # Initialize the type with what we find in the
    ptype = get_nonmissing_typeof_uniontype(fieldtype(datatype,propname))

    # Check if there is a type override for this property, if not we
    #   use the property type

    if (isdefined(orm_module,:types_override)
        && propname in collect(keys(orm_module.types_override)))
        ptype = PostgresORM.get_orm(dummy_object).types_override[propname]
    end
    return ptype
end


function util_convert_namedtuple_to_object(props::NamedTuple, object_type::DataType,
                                           retrieve_complex_props::Bool,
                                           dbconn::Union{LibPQ.Connection,Missing})


    # Initialize the properties of the object with what was
    #   retrieved fom database
    # NOTE: we need to force the dictionary to accept any type of value
    props_dict::Dict{Symbol,Any} = namedtuple2dict(props)


    # At this point we have a dict of values of the dataframe as returned by
    #   the query: no renaming no encapuslation for complex properties
    #   (eg.: film_id, film_release_year, actor_id).
    # We transform this dict to another dict that suits the hierarchy of the julia
    #   data model
    #  eg. {film_id, film_release_year, actor_id} becomes {film{id,release_year}, actor{id}}
    # @info keys(props_dict)
    # @info length(props_dict[:possible_values_as_str_arr])
    props_dict =
        util_convert_flatdictfromdb_to_structuredrenameddict(props_dict,
                                                             object_type)

    # @info keys(props_dict)
    # @info length(props_dict[:possibleValuesAsStrArr])
    # Now that the dict follows the structure of the datamodel we transform it
    util_dict2entity(props_dict,
                     object_type,
                     true, # building from database result
                     retrieve_complex_props,
                     dbconn)

end

function util_convert_flatdictfromdb_to_structuredrenameddict(flatdict::Dict,
                                                              object_type::DataType)
    sample_object = object_type()
    orm_module = get_orm(sample_object)

    result = Dict()

    # Loop over the properties of the struct and try to get the corresponding
    #   values in the flat dict
    for (propname,prop_colnames) in util_get_columns_selection_and_mapping(orm_module)

        # Get the proptype in order to know if we are dealing with a complex
        #   property or not
        proptype = util_get_property_real_type(object_type, propname)

        # if the property is a complex prop we build a dict with the IDs of
        #    the complex object as described in the ORM of the complex property
        if proptype <: IEntity

            result[propname] = Dict()

            # Retrieve the type of the complex object
            complexprop_instance = proptype()
            complexprop_idprops = util_get_ids_props_names(complexprop_instance)
            complexprop_orm = get_orm(complexprop_instance)

            # Check that the number of columns for the FK is consistent with
            #   the number of properties used as PK in the targeted object
            if length(complexprop_idprops) != length(tovector(prop_colnames))
                error("There is an inconsistency in the ORMs definition,
                type[$object_type] has property[$propname] of type[$proptype]
                which is mapped with $(length(tovector(prop_colnames))) columns
                but type[$proptype] has only $(length(complexprop_idprops)) IDs
                properties")
            end

            # If there is a composed foreign key we need to correctly map the
            #   column values to the column ids in the target table
            if isa(prop_colnames, Array) && length(prop_colnames) > 1

                # Loop over the FK columns and use the PKs in the same order
                # TODO: Handle the case where the order of the FKs and PKs columns
                #         is not the same
                counter = 0
                for colname in prop_colnames

                    # Get the value from the flatdict (if exists)
                    if haskey(flatdict, Symbol(colname))
                        colvalue = flatdict[Symbol(colname)]
                    else
                        break
                    end

                    complexprop_idprop = complexprop_idprops[counter+=1]
                    result[propname][complexprop_idprop] = colvalue


                end

            # If it is a non componsed foreign key then we can simply use the
            #   id property of the targeted object
            else
                complexprop_idprop = complexprop_idprops[1]
                complexprop_colname = Symbol(tovector(prop_colnames)[1])
                if haskey(flatdict, complexprop_colname)
                    result[propname][complexprop_idprop] = flatdict[complexprop_colname]
                end

            end # ENFOF `if isa(prop_colnames, Array) && length(prop_colnames) > 1`



        # If the property is simple then we just look for the value in the dict
        else
            colname = Symbol(tovector(prop_colnames)[1])
            if haskey(flatdict,colname)
                result[propname] = flatdict[colname]
            end
        end # ENDOF `if proptype <: IEntity`

    end # ENDOF `for (propname,prop_colnames) in util_get_columns_selection_and_mapping(orm_module)`

    return result


end

# Create the selection as expected by the Query.jl macro
# Eg: `{id = i.document_id, lastname = i.lastname}` )
function util_get_curlybrackets_expression_for_linq_select(
        columns_selection_and_mapping::Dict)

    target_properties = string.(keys(columns_selection_and_mapping))
    source_cols =  values(columns_selection_and_mapping)
    columns_selection_and_mapping_tmp = "{" * join(string.(target_properties) .* " = i." .* source_cols,", ") * "}"

    Meta.parse(columns_selection_and_mapping_tmp)
end

function util_remove_unmapped_properties_from_dict(
        props::Dict,
        columns_selection_and_mapping::Dict)
    @from i in props begin
    @where i.first in collect(keys(columns_selection_and_mapping))
    @select i
    @collect Dict
    end
end


function util_remove_trackchanges_properties_from_dict(
        props::Dict,
        orm_module::Module)

    if (isdefined(orm_module,:track_changes)
        && getproperty(orm_module,:track_changes))

        trackchanges_properties = Symbol[]
        if isdefined(orm_module,:creator_property)
            push!(trackchanges_properties,orm_module.creator_property)
        end
        if isdefined(orm_module,:editor_property)
            push!(trackchanges_properties,orm_module.creator_property)
        end
        if isdefined(orm_module,:creation_time_property)
            push!(trackchanges_properties,orm_module.creation_time_property)
        end
        if isdefined(orm_module,:update_time_property)
            push!(trackchanges_properties,orm_module.update_time_property)
        end

        if length(trackchanges_properties) == 0
            return props
        end

        @from i in props begin
        @where !(i.first in trackchanges_properties)
        @select i
        @collect Dict
        end

    else
        return props
    end
end

function util_replace_complex_types_by_id(props::Dict, mapping::Dict, data_type::DataType)

    mapping = deepcopy(mapping)
    orm_module = get_orm(data_type())

    # NOTE: We loop on the result of a filter that does nothing because if not
    #        the pairs that are added dynamically in the loop will be looped
    #        over as well
    for (prop_symbol, prop_val) in filter(x -> true, props)


      _fieldtype = util_get_property_real_type(data_type, prop_symbol)

      # NOTE: We test on the fieldtype because the property value can be missing
      if _fieldtype <: IEntity

          # @info "Replace[$prop_symbol] with ids"

          dummy_propval = _fieldtype() # Used in case the prop val is missing

          prop_orm_module = get_orm(_fieldtype())
          prop_columns_selection_and_mapping =
            util_get_columns_selection_and_mapping(prop_orm_module)

          # Retrieve the names of the ID properties in the target struct
          id_props_in_target_struct = util_get_ids_props_names(_fieldtype())

          # @info "id_props_in_target_struct[$id_props_in_target_struct] ($_fieldtype)"

          # Whatever we get from the mapping we make it a vector
          idcols = tovector(mapping[prop_symbol])

          prop_val_as_dict =
              PostgresORMUtil.getproperties_asdict(
                if ismissing(prop_val) dummy_propval else prop_val end,
                 true # include missing
                 )

          prop_val_ids_values =
              filter!(x -> first(x) in id_props_in_target_struct,
                      prop_val_as_dict)
          prop_val_ids_values = util_replace_complex_types_by_id(
              prop_val_ids_values,
              util_get_columns_selection_and_mapping(
                if ismissing(prop_val) dummy_propval else prop_val end
               ),
              _fieldtype)

          if length(idcols) != length(prop_val_ids_values)
              error_msg = ""
              error_msg *= "Problem while flattening property[$prop_symbol] of"
              error_msg *= " an $data_type. The number of columns[$(length(idcols))]"
              error_msg *= " found in ORM[$orm_module] does not match the number"
              error_msg *= " of columns[$(length(prop_val_ids_values))] found"
              error_msg *= " for the IDs in ORM [$prop_orm_module]"
              error(error_msg)
          end

          ids_props_names = collect(keys(prop_val_ids_values))
          ids_cols_names = util_getcolumns(ids_props_names,
                                           prop_columns_selection_and_mapping)
          ids_props_values = collect(values(prop_val_ids_values))

          # Make sure the values are ordered in the same order as the one given
          #  by the mapping of the target entity's ORM
          idvalues = []

          prop_colnames_in_target_type = util_get_ids_cols_names(prop_orm_module)
          for pcol in prop_colnames_in_target_type
              for (n,c,v) in zip(ids_props_names,ids_cols_names,ids_props_values)
                  if (pcol == c)
                      push!(idvalues,v)
                  end
              end
          end

          for (k,v) in zip(idcols, idvalues)
             # This prevents a property using the same primary columns to
             #   overwrite a non missing value
             if ismissing(v) && haskey(props,Symbol(k)) && !ismissing(props[Symbol(k)])
               continue
             else
               props[Symbol(k)] = v
             end
          end

          # for (n,c,v,cbis) in zip(ids_props_names,ids_cols_names,ids_props_values,idcols)
          #     @info "$_fieldtype -> $n, $c, $v"
          #     props[Symbol(cbis)] = v
          # end

          # counter = 0
          # for (k,v) in prop_val_ids_values
          #     id_column_name = idcols[counter+=1] # the name as used by the FK
          #     props[Symbol(id_column_name)] = v
          # end

          # Remove the previous reference that has been replaced
          delete!(props,prop_symbol)

      # Convert vector of IEntity
      elseif eltype(prop_val) <: IEntity
          props[prop_symbol] = Vector{Any}()
          for e in prop_val

              push!(props[prop_symbol],
              getproperty(e,
                          PostgresORM.get_orm(e).id_property))
          end
      end # ENDOF if isa(prop_val,IEntity)

  end # ENDOF for (prop_symbol, prop_val) in props

  return props
end

function util_replace_enums_by_id_if_needed(props::Dict,
                                            orm_module::Module,
                                            dbconn::LibPQ.Connection)

    table_name = util_get_table_name(orm_module)
    schema = util_get_schema_name(orm_module)
    columns_selection_and_mapping = util_get_columns_selection_and_mapping(orm_module)

    for (prop_symbol, prop_val) in props
      if typeof(prop_val) <: Enum
          colname = columns_selection_and_mapping[prop_symbol]
          # Chech in the database if the enum os stored as a numeric
          if util_is_column_numeric(dbconn,
                                    table_name,
                                    schema,
                                    colname)
              props[prop_symbol] = enum2int(prop_val)
          end

      end
    end
    return props
end

"""
    util_replace_empty_vector_of_enums_by_missing(props::Dict)

Replace empty vector of an enum by missing. This allows developers to avoid testing both for
nullity and emptiness of the property
"""
function util_replace_empty_vector_of_enums_by_missing(props::Dict)
    for (prop_symbol, prop_val) in props
        if typeof(prop_val) <: Vector{T} where T <: Base.Enums.Enum
            if isempty(prop_val)
                props[prop_symbol] = missing
            end
        end
    end
    return props
end

function util_replace_dict_types(props::Dict,
                                 orm_module::Module,
                                 dbconn::LibPQ.Connection)
    for (prop_symbol, prop_val) in props
       # @info "$prop_symbol is a dict: "
       if isa(prop_val,Dict)
           props[prop_symbol] = JSON.json(prop_val)
       end
    end
    return props
end

function util_get_ids_props_names(orm_module::Module)
    if isdefined(orm_module,:get_id_props)
        return orm_module.get_id_props()
    # This is support for the legacy way of declaring the id properties
    elseif isdefined(orm_module,:id_property)
        return PostgresORMUtil.tovector(orm_module.id_property)
    else
        error("orm_module[$orm_module] is missing a definition for the id property")
    end
end

function util_get_ids_props_names(o::IEntity)
    return util_get_ids_props_names(PostgresORM.get_orm(o))
end

function util_get_table_name(orm_module::Module)

    tablename = if isdefined(orm_module,:get_table_name)
            orm_module.get_table_name()
        # Support of legacy naming
        elseif isdefined(orm_module,:gettablename)
            orm_module.gettablename()
        else
            error("orm_module[$orm_module] is missing 'get_table_name()''")
        end

    # Handle the case where the schema has been put in the table name
    if occursin(".",tablename)
        schema_and_table_names = string.(split(tablename,'.'))
        schema = schema_and_table_names[1]
        tablename = schema_and_table_names[2]
        return tablename
    end
    return tablename
end

function util_get_table_name(o::IEntity)
    return util_get_table_name(PostgresORM.get_orm(o))
end

function util_get_table_with_schema_name(orm_module::Module)
    return "$(util_get_schema_name(orm_module)).$(util_get_table_name(orm_module))"
end

function util_get_table_with_schema_name(o::IEntity)
    return util_get_table_with_schema_name(PostgresORM.get_orm(o))
end

function util_get_schema_name(orm_module::Module)

    if isdefined(orm_module,:get_schema_name)
        return orm_module.get_schema_name()
    # This is support for legacy ORMs where the schema was declared together with
    #   the table name
    elseif isdefined(orm_module,:gettablename)
        tablename = orm_module.gettablename()
        if occursin(".",tablename)
            schema_and_table_names = string.(split(tablename,'.'))
            schema = schema_and_table_names[1]
            return schema
        else
            return "public"
        end
    elseif isdefined(orm_module,:get_table_name)
        tablename = orm_module.get_table_name()
        if occursin(".",tablename)
            schema_and_table_names = string.(split(tablename,'.'))
            schema = schema_and_table_names[1]
            return schema
        else
            error("orm_module[$orm_module] is missing 'get_schema_name()''")
        end
    else
        error("orm_module[$orm_module] is missing 'get_schema_name()''")
    end

end

function util_get_schema_name(o::IEntity)
    return util_get_schema_name(PostgresORM.get_orm(o))
end

function util_get_columns_selection_and_mapping(orm_module::Module)
    if isdefined(orm_module,:get_columns_selection_and_mapping)
        return orm_module.get_columns_selection_and_mapping()
    # This is support for the legacy way of declaring the id properties
    elseif isdefined(orm_module,:columns_selection_and_mapping)
        return orm_module.columns_selection_and_mapping
    else
        error("orm_module[$orm_module] is missing 'get_columns_selection_and_mapping'")
    end
end

function util_get_columns_selection_and_mapping(o::IEntity)
    return util_get_columns_selection_and_mapping(PostgresORM.get_orm(o))
end

function util_get_onetomany_counterparts(orm_module::Module)
    if isdefined(orm_module,:get_onetomany_counterparts)
        return orm_module.get_onetomany_counterparts()
    # This is support for the legacy way of declaring the id properties
    elseif isdefined(orm_module,:onetomany_counterparts)
        return orm_module.onetomany_counterparts
    else
        error("orm_module[$orm_module] is missing 'get_onetomany_counterparts'")
    end
end

function util_get_onetomany_counterparts(o::IEntity)
    return util_get_onetomany_counterparts(PostgresORM.get_orm(o))
end

function util_get_types_override(orm_module::Module)
    if isdefined(orm_module,:get_types_override)
        return orm_module.get_types_override()
    # This is support for the legacy way of declaring the id properties
    elseif isdefined(orm_module,:types_override)
        return orm_module.types_override
    else
        error("orm_module[$orm_module] is missing 'get_types_override'")
    end
end

function util_get_types_override(o::IEntity)
    return util_get_types_override(PostgresORM.get_orm(o))
end

function util_get_track_changes(orm_module::Module)
    if isdefined(orm_module,:get_track_changes)
        return orm_module.get_track_changes()
    # This is support for the legacy way of declaring the id properties
    elseif isdefined(orm_module,:track_changes)
        return orm_module.track_changes
    else
        return false # default
    end
end

function util_get_track_changes(o::IEntity)
    return util_get_track_changes(PostgresORM.get_orm(o))
end

function util_get_creator_property(orm_module::Module)
    if isdefined(orm_module,:get_creator_property)
        return orm_module.get_creator_property()
    # This is support for the legacy way of declaring the id properties
    elseif isdefined(orm_module,:creator_property)
        return orm_module.creator_property
    else
        return missing
    end
end

function util_get_creator_property(o::IEntity)
    return util_get_creator_property(PostgresORM.get_orm(o))
end

function util_get_editor_property(orm_module::Module)
    if isdefined(orm_module,:get_editor_property)
        return orm_module.get_editor_property()
    # This is support for the legacy way of declaring the id properties
    elseif isdefined(orm_module,:editor_property)
        return orm_module.editor_property
    else
        return missing
    end
end

function util_get_editor_property(o::IEntity)
    return util_get_editor_property(PostgresORM.get_orm(o))
end

function util_get_creation_time_property(orm_module::Module)
    if isdefined(orm_module,:get_creation_time_property)
        return orm_module.get_creation_time_property()
    # This is support for the legacy way of declaring the id properties
    elseif isdefined(orm_module,:creation_time_property)
        return orm_module.creation_time_property
    else
        return missing
    end
end

function util_get_creation_time_property(o::IEntity)
    return util_get_creation_time_property(PostgresORM.get_orm(o))
end

function util_get_update_time_property(orm_module::Module)
    if isdefined(orm_module,:get_update_time_property)
        return orm_module.get_update_time_property()
    # This is support for the legacy way of declaring the id properties
    elseif isdefined(orm_module,:update_time_property)
        return orm_module.update_time_property
    else
        return missing
    end
end

function util_get_update_time_property(o::IEntity)
    return util_get_update_time_property(PostgresORM.get_orm(o))
end

function util_get_ids_cols_names(orm_module::Module)
    props = util_get_ids_props_names(orm_module)
    columns_selection_and_mapping = util_get_columns_selection_and_mapping(orm_module)
    result = []
    for p in props
        propcols = tovector(columns_selection_and_mapping[p])
        push!(result,propcols...)
    end
    return result
end

function util_get_ids_cols_names(o::IEntity)
    orm_module = PostgresORM.get_orm(o)
    util_get_ids_cols_names(orm_module)
end

function util_prettify_id_values_as_str(object::T) where T <: IEntity

    idprops_with_values = []
    idprops = util_get_ids_props_names(object)

    for idprop in idprops
        idpropvalue = getproperty(object, idprop)
        if idpropvalue isa IEntity
            push!(idprops_with_values,
                  (name = idprop, value = util_prettify_id_values_as_str(idpropvalue)))
        else
            push!(idprops_with_values,
                  (name = idprop, value = string(idpropvalue)))
        end
    end

    # If there is only one value no need to specify the name of the property
    if length(idprops_with_values) == 1
        return string(first(idprops_with_values).value)
    end

    result = ""
    strings = []
    for idprop_with_value in idprops_with_values
        push!(strings,"$(idprop_with_value.name)[$(idprop_with_value.value)]")
    end
    return join(strings,", ")

    # return result

    # return idprops_with_values
    # return string(idprops_with_values)

    # str = string(values)
    # my_match = match(r"^Any\[(.*)\]$",str)
    # if isnothing(my_match)
    #     my_match = match(r"^\[(.*)\]$",str)
    # end
    # str = string(collect(my_match.captures)[1])
    # str = replace(str,", missing"=>"")
    # str = replace(str,"missing, "=>"")
    # return str
end
