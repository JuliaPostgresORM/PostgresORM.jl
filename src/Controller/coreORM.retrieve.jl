# query_string = "SELECT a.* FROM appuser a
#                     WHERE a.login = \$1"
function retrieve_entity(filter_object::Union{IEntity,Missing},
                         data_type::DataType,
                         table_name::String,
                         columns_selection_and_mapping::Dict,
                         retrieve_complex_props::Bool,
                         dbconn::LibPQ.Connection)

    query_string = "SELECT o.* FROM " * table_name * " o "

    # Initialize the properties variables so that we can just test it's size
    #   later on in the function
    props = Dict{Symbol,Any}()

    # Instantiate an empty instance of the data type just to get the module
    orm_module = PostgresORM.get_orm(data_type())

    if !ismissing(filter_object)
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
                query_string *= " o.$columnname = \$$n " # eg. 'a.login = \$1'

            end
        end
    end

    # prepared_query = LibPQ.prepare(dbconn,
    #                                query_string)

    # Prepare the query aruments
    # NOTE: It would be more elegant to convert the keys in an array of String
    #         but I didn't find a way to do it
    query_args = collect(values(props))

    result = execute_query_and_handle_result(query_string,
                                             data_type,
                                             query_args,
                                             columns_selection_and_mapping,
                                             retrieve_complex_props,
                                             dbconn)

    return(result)

end

function execute_query_and_handle_result(query_string::String,
                                         data_type::DataType,
                                         query_args::Union{Vector,Missing},
                                         retrieve_complex_props::Bool,
                                         dbconn::LibPQ.Connection)

    # Create a dummy object to get the ORM module
    orm_module = PostgresORM.get_orm(data_type())

    columns_selection_and_mapping = util_get_columns_selection_and_mapping(orm_module)

    execute_query_and_handle_result(query_string,
                                    data_type,
                                    query_args,
                                    columns_selection_and_mapping,
                                    retrieve_complex_props,
                                    dbconn)

end

function execute_plain_query(query_string::String,
                             query_args::Union{Vector,Missing},
                             dbconn::LibPQ.Connection)

   prepared_query = LibPQ.prepare(dbconn,
                                  query_string)

   if ismissing(query_args)
       query_args = []
   end

   query_result = execute(prepared_query,
                          query_args
                          ;throw_error=true)

    # Get the result as a dataframe
    data = DataFrame(query_result)

    # Close the result
    close(query_result)

    return(data)

end

function execute_query_and_handle_result(query_string::String,
                                         data_type::DataType,
                                         query_args::Union{Vector,Missing},
                                         columns_selection_and_mapping::Dict,
                                         retrieve_complex_props::Bool,
                                         dbconn::LibPQ.Connection)

     prepared_query = LibPQ.prepare(dbconn,
                                    query_string)

     if ismissing(query_args)
         query_args = []
     end

     query_result = execute(prepared_query,
                            query_args
                            ;throw_error=true)

      # Get the result as a dataframe
      data = DataFrame(query_result)

      # Close the result
      close(query_result)

      # Format the result to be mapped to the data model
      result = util_clean_and_rename_query_result(data,columns_selection_and_mapping)

      result = dataframe2vector_of_namedtuples(result)

      result =
         util_convert_namedtuple_to_object.(result,data_type,
                                        retrieve_complex_props,
                                        dbconn)
      return result
end

function retrieve_entity(filter_object::Union{IEntity,Missing},
                         orm_module::Module,
                         retrieve_complex_props::Bool,
                         dbconn::LibPQ.Connection)

     retrieve_entity(filter_object,
                     orm_module.data_type,
                     util_get_table_with_schema_name(orm_module),
                     util_get_columns_selection_and_mapping(orm_module),
                     retrieve_complex_props,
                     dbconn)
end

function retrieve_entity(filter_object::IEntity,
                         retrieve_complex_props::Bool,
                         dbconn::LibPQ.Connection)

         retrieve_entity(filter_object,
                         PostgresORM.get_orm(filter_object),
                         retrieve_complex_props,
                         dbconn)
end

function retrieve_one_entity(filter_object::T,
                             retrieve_complex_props::Bool,
                             dbconn::LibPQ.Connection) where T <: PostgresORM.IEntity

      results = retrieve_entity(filter_object,
                                retrieve_complex_props,
                                dbconn)

      if length(results) > 1
          error("Too many results for filter_object[$filter_object]")
      end
      if length(results) == 0
          return missing
      end
      result = results[1]
      return result
end
