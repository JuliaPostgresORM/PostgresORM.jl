# query_string = "INSERT INTO appuser (lastname,login)
#                 VALUES (\$1, \$2)"
function create_entity!(new_object::IEntity,
                       table_name::String,
                       columns_selection_and_mapping::Dict{Symbol,<:Any},
                       dbconn::LibPQ.Connection;
                       creator::Union{IEntity,Missing} = missing)

    # tick()

    data_type = typeof(new_object)
    orm_module = PostgresORM.get_orm(new_object)

    query_string = "INSERT INTO " * table_name

    #
    # Enrich the created object with the creator and creation time if needed
    #
    creator_property = util_get_creator_property(orm_module)
    if !ismissing(creator_property)
         # Only set the creator property if it is empty because the rest of the
         #  application may want to set it (eg. if importing data)
         if ismissing(getproperty(new_object,creator_property))
             setproperty!(new_object,
                          creator_property,
                          creator)
         # If the object has the creator property set, use it
         else
             creator = getproperty(new_object,creator_property)
         end
    end

    creation_time_property = util_get_creation_time_property(orm_module)
    if !ismissing(creation_time_property)
        # Only set the creation time if it is empty because the rest of the
        #  application may want to set it (eg. if importing data)
        if ismissing(getproperty(new_object, creation_time_property))
            setproperty!(new_object,
                         creation_time_property,
                         now(Dates.UTC))
        end
    end


    # Record the state of the attributes in the modification table
    if util_get_track_changes(orm_module)

         #
         # Create the modification entries
         #
         action_id = uuid4()

         # Get the editor id if any
         editor_id = if ismissing(creator)
           missing
         else
             util_prettify_id_values_as_str(creator)
         end

         modifs = Modification[]

         previous_state_props = Dict{Symbol,Any}()

         props_modified =
            diff_dict(previous_state_props,
                      util_get_entity_props_for_comparison(new_object, dbconn))

         for (k,v) in props_modified

             modif = Modification(entity_type =  string(data_type),
                                  entity_id = missing, # not available at this moment
                                  attrname = string(k),
                                  oldvalue = ismissing(v.old) ? missing : string(v.old),
                                  newvalue = ismissing(v.new) ? missing : string(v.new),
                                  appuser_id = editor_id,
                                  creation_time = now(Dates.UTC),
                                  action_type = CRUDType.create,
                                  action_id = action_id)
             # Store the modification in a vector for the moment, we need the ID
             #  before we can persist the modifications
             push!(modifs, modif)
             # ModificationORM.create_modification(modif)

         end

    end # ENDOF if track_changes

    props = util_get_entity_props_for_db_actions(new_object,
                                                 dbconn,
                                                 false # no need to include missing values at insertion
                                                  )

    # Prepare the vectors used for creating the query
    properties_names = collect(keys(props))
    column_names = util_getcolumns(properties_names, columns_selection_and_mapping)
    properties_values = collect(values(props))

    # Loop over the properties of the object and
    #   build the appropriate list of columns
    if length(props) > 0
        query_string *= "(" * join(column_names,",") * ")" # '(lastname,login)'
    else
        # TODO throw_error
    end

    # Add the prepared statement indexes
    query_indexes = string.(collect(1:length(properties_names)))
    query_indexes = string.("\$",query_indexes)
    query_string *= (" VALUES ("
                     * join(query_indexes,",")
                     * ") " # '(lastname,login)'
                     * "RETURNING *");

    prepared_query = LibPQ.prepare(dbconn,
                                   query_string)

# @info "query is prepared"
# laptimer()

    # @info query_string
    # @info properties_values

    query_result = execute(prepared_query,
                           properties_values
                           ;throw_error=true)

# @info "query is executed"
# laptimer()

     # Get the result as a dataframe
     data = DataFrame(query_result)

     # Close the result
     close(query_result)

 # @info "query is closed"
 # laptimer()

     result = util_clean_and_rename_query_result(data,columns_selection_and_mapping)

 # @info "columns are renamed"
 # laptimer()

     result = dataframe2vector_of_namedtuples(result)

 # @info "dataframe is transformed to vector of named tuple"
 # laptimer()

     result =
        util_convert_namedtuple_to_object.(result,data_type,
                                           true, # retrieve_complex_props
                                           dbconn)

# @info "vector of named tuple is transformed to vector of objects"
# laptimer()

     # Returns the first element only because we create only one object
     result = result[1]

     util_overwrite_props!(result, # src entity
                           new_object, # target entity
                           true # Ignore missing properties like all the
                                #    unmapped properties)
                           )

     # Enrich the modification with the entity ID and persist it to database
     if util_get_track_changes(orm_module)

         idprops = util_get_ids_props_names(result)

         # Create a string representation of the ID properties values.
         id_value_as_str = util_prettify_id_values_as_str(result)

         for m in modifs
             setproperty!(m,
                          :entity_id,
                          id_value_as_str)

             # If the attribute is the ID of the entity we set the ID as the 'newvalue'
             # if m.attrname == string(orm_module.id_property)
             #     setproperty!(m,
             #                  :newvalue,
             #                  id_value_as_str)
             # end

             create_entity!(m, dbconn)
         end
     end

# tock()

     return new_object
end

function create_entity!(new_object::IEntity,
                       orm_module::Module,
                       dbconn::LibPQ.Connection;
                       creator::Union{IEntity,Missing} = missing)
   create_entity!(new_object,
                 util_get_table_with_schema_name(orm_module),
                 util_get_columns_selection_and_mapping(orm_module),
                 dbconn;
                 creator = creator)
end

function create_entity!(new_object::IEntity,
                       dbconn::LibPQ.Connection;
                       creator::Union{IEntity,Missing} = missing)

   create_entity!(new_object,
                 PostgresORM.get_orm(new_object),
                 dbconn;
                 creator = creator)
end


"""
Persist to database using Postgresql 'COPY'
"""
function create_in_bulk_using_copy(entities::Vector{T},
                                   dbconn::LibPQ.Connection)  where T <: PostgresORM.IEntity

    if isempty(entities)
        @info "Empty vector was passed to create_in_bulk_using_copy. Do nothing"
        return(0)
    end

   # dummy = T() # Does not work because the vector may be a vector of abstract types
   dummy = typeof(entities[1])()
   dataType = typeof(dummy)
   orm = PostgresORM.get_orm(dummy)
   tableName = util_get_table_name(orm)
   schemaName = util_get_schema_name(orm)
   columns_selection_and_mapping = util_get_columns_selection_and_mapping(orm)

   # Loop through the entities and check if there is a value for the fields that
   #   are reputed missing so far. Remove the field from the missing fields if
   #   there is a value.
   missing_fields = [fieldnames(dataType)...] # Initialize with all the fields
   non_missing_fields = Symbol[]
   for missing_field in missing_fields
       for e in entities
           if !ismissing(getproperty(e, missing_field))
               push!(non_missing_fields,missing_field)
               break
           end
       end
   end
   filter!(x -> !(x in non_missing_fields), missing_fields)

   # Retrieve the names of the columns from a dummy instance
   column_names = begin

       props_dummy = util_get_entity_props_for_db_actions(
                   dummy,
                   dbconn,
                   true # Include missing values
                  ;exclude_props = missing_fields
                 )

       properties_names = collect(keys(props_dummy))
       util_getcolumns(properties_names, columns_selection_and_mapping)

   end

   result::Int64 = 0
   try

        rowStrings = imap(entities) do entity

            rowStringArr = []

            props = util_get_entity_props_for_db_actions(
                        entity,
                        dbconn,
                        true # Include missing values coz all lines in the COPY
                             #   must have teh ame number of elements
                       ;exclude_props = missing_fields
                      )

            properties_values = []
            for property_name in properties_names
                push!(properties_values,props[property_name])
            end

            # properties_values = collect(values(props))

            for value in properties_values
                if ismissing(value)
                    push!(rowStringArr,"")
                else
                    if isa(value,String)
                        value = replace(value, r"\n" => " ") # Replace line breaks by space
                        value = replace(value, r"\"" => "\"\"") # Escape the double quotes
                        value = "\"$value\"" # Put the strings in between quotes so that
                                             #   we can have the delimeter appear in the strings
                    end
                    push!(rowStringArr,value)
                end
            end

            oneRowStr = "$(join(rowStringArr,';'))\n"
            oneRowStr
            # "$(row.rechor_id),$(row.rechor_sm),$(row.journeeExploitation)\n"

        end #ENDOF do row

        # return(rowStrings)
        copyin =
             LibPQ.CopyIn("COPY $schemaName.$tableName($(join(column_names,',')))
                             FROM STDIN (FORMAT CSV, DELIMITER ';', QUOTE '\"');", rowStrings)

        resultOfExecution = execute(dbconn, copyin; throw_error=false)

        # Return the number of rows inserted
        result = LibPQ.num_affected_rows(resultOfExecution)

   catch e
      rethrow(e)
   end

   return result

end
