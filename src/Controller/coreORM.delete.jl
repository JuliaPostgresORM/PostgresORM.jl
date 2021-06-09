# query_string = "DELETE FROM appuser WHERE id = \$1"
function delete_entity(deleted_object::IEntity,
                       data_type::DataType,
                       table_name::String,
                       columns_selection_and_mapping::Dict{Symbol,<:Any},
                       id_properties::Vector{Symbol},
                       dbconn::LibPQ.Connection;
                       editor::Union{IEntity,Missing} = missing)

    query_string = "DELETE FROM " * table_name

    # Check that we have a filter object
    if ismissing(deleted_object)
        throw(DomainError("You must specify an object to delete"))
    end

    # Loop over the properties of the object and build the appropriate where clause
    # props = PostgresORMUtil.getproperties_asdict(deleted_object,false)
    # props = util_remove_unmapped_properties_from_dict(props,
                                                      # columns_selection_and_mapping)

    props = util_get_entity_props_for_db_actions(deleted_object,
                                                 dbconn,
                                                 false # do not include missing
                                                       #  (although it doesn't make any difference anyway)
                                                 )

    # Compare versions if needed, by retrieving the current state of the object
    #   in the database
    orm_module = PostgresORM.get_orm(deleted_object)
    if util_get_track_changes(orm_module)

        # Create a string representation of the ID properties values.
        id_value_as_str = util_prettify_id_values_as_str(deleted_object)

        # Get the editor id if any
        editor_id = if ismissing(editor)
            missing
        else
            util_prettify_id_values_as_str(editor)
        end

        action_id = uuid4()

        modif = Modification(entity_type =  string(data_type),
                             entity_id = id_value_as_str,
                             appuser_id = editor_id,
                             creation_time = now(Dates.UTC),
                             action_type = CRUDType.delete,
                             action_id = action_id)
        create_entity!(modif,dbconn)

     end # if track_changes

     # Prepare the vectors used for creating the query
     properties_names = collect(keys(props))
     properties_values = collect(values(props))

     prepared_statement_args_values = Any[] # Holds the values of the prepared statement
     prepared_statement_args_counter = 0

     # Add the 'WHERE' clause:
     # id_columnname = columns_selection_and_mapping[id_property]
     # query_string *= " WHERE $id_columnname = \$1"
     # push!(prepared_statement_args_values,
     #      getproperty(deleted_object, id_property))

     # Add the 'WHERE' clause:
     # Loop over the ID properties
     query_string *= " WHERE "
     where_clause_elts = Vector{String}()
     # An object can have several ID properties
     for id_property in util_get_ids_props_names(deleted_object)
          # An ID property can have several columns (eg. when the property is a
          #   complex property that has several IDs)
          id_columnnames = tovector(columns_selection_and_mapping[id_property])
          for id_columnname in id_columnnames
              where_clause_elt =  "$id_columnname = \$$(prepared_statement_args_counter+=1)"
              push!(where_clause_elts, where_clause_elt)
              # If the ID property is a complex prop, then the value is stored
              #   under the name of the column name
              if isa(getproperty(deleted_object, id_property),IEntity)
                  push!(prepared_statement_args_values,
                        props[Symbol(id_columnname)])
              else
                  push!(prepared_statement_args_values,
                        props[id_property])
              end

          end
     end
     query_string *= join(where_clause_elts, " AND ")


     prepared_query = LibPQ.prepare(dbconn,
                                   query_string)

     # @info query_string
     # @info prepared_statement_args_values

     # Prepare the query aruments
     query_result = execute(prepared_query,
                           prepared_statement_args_values
                           ;throw_error=true)

      # Get the result as a dataframe
      result = LibPQ.num_affected_rows(query_result)

      # Close the result
      close(query_result)

      return result

end

function delete_entity(deleted_object::IEntity,
                       orm_module::Module,
                       dbconn::LibPQ.Connection;
                       editor::Union{IEntity,Missing} = missing)

    delete_entity(deleted_object,
                  orm_module.data_type,
                  util_get_table_with_schema_name(orm_module),
                  util_get_columns_selection_and_mapping(orm_module),
                  util_get_ids_props_names(deleted_object),
                  dbconn;
                  editor = editor)
end

function delete_entity(deleted_object::IEntity,
                       dbconn::LibPQ.Connection;
                       editor::Union{IEntity,Missing} = missing
                       )
    delete_entity(deleted_object,
                  PostgresORM.get_orm(deleted_object),
                  dbconn;
                  editor = editor)
end


# query_string = "DELETE FROM appuser WHERE id = \$1 AND attr1 = \2 AND ..."
function delete_entity_alike(filter_object::IEntity,
                             data_type::DataType,
                             table_name::String,
                             columns_selection_and_mapping::Dict{Symbol,<:Any},
                             dbconn::LibPQ.Connection;
                             editor::Union{IEntity,Missing} = missing)

    query_string = "DELETE FROM " * table_name

    # Check that we have a filter object
    if ismissing(filter_object)
        throw(DomainError("You must specify an object to delete"))
    end

    # Loop over the properties of the object and build the appropriate where clause
    props = PostgresORMUtil.getproperties_asdict(filter_object,false)
    props = util_remove_unmapped_properties_from_dict(props,
                                                      columns_selection_and_mapping)


      # Instantiate an empty instance of the data type just to get the module
      orm_module = PostgresORM.get_orm(data_type())

      # Loop over the properties of the object and build the appropriate where clause
      props = util_get_entity_props_for_db_actions(filter_object,
                                                   dbconn,
                                                   false # do not include missing
                                                   )
      if length(props) > 0
          n = 0
          query_string *= " WHERE "
          for (propertyname,value) in props
              n += 1
              # Add the 'AND' if it's not the first restriction
              if n > 1
                  query_string *= " AND "
              end

              # NOTE: The mapping may not have the properties because some of the
              #          properties are the columns names of the complex objects
              #          which are added at runtime
              columnname = if haskey(columns_selection_and_mapping, propertyname)
                              columns_selection_and_mapping[propertyname]
                           else
                               propertyname
                           end

              # Add the restriction
              query_string *= " $columnname = \$$n " # eg. 'a.login = \$1'

          end
      end

     # prepared_query = LibPQ.prepare(dbconn,
     #                                query_string)

     # Prepare the query aruments
     # NOTE: It would be more elegant to convert the keys in an array of String
     #         but I didn't find a way to do it
     query_args = collect(values(props))

     prepared_query = LibPQ.prepare(dbconn,
                                   query_string)

     # Prepare the query aruments
     query_result = execute(prepared_query,
                            query_args
                           ;throw_error=true)

      # Get the result as a dataframe
      result = LibPQ.num_affected_rows(query_result)

      # Close the result
      close(query_result)

      return result

end

function delete_entity_alike(filter_object::IEntity,
                       orm_module::Module,
                       dbconn::LibPQ.Connection;
                       editor::Union{IEntity,Missing} = missing)

    delete_entity_alike(filter_object,
                  orm_module.data_type,
                  util_get_table_with_schema_name(orm_module),
                  util_get_columns_selection_and_mapping(orm_module),
                  dbconn;
                  editor = editor)
end

function delete_entity_alike(filter_object::IEntity,
                       dbconn::LibPQ.Connection;
                       editor::Union{IEntity,Missing} = missing
                       )
    delete_entity_alike(filter_object,
                  PostgresORM.get_orm(filter_object),
                  dbconn;
                  editor = editor)
end
