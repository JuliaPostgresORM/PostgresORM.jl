# NOTE: This also updates the properties of the elements of the vector
function update_vector_property!(updated_object::IEntity,
                                 updated_property::Symbol,
                                 dbconn::Union{Missing, LibPQ.Connection};
                                 editor::Union{Missing, IEntity} = missing)

    # Missing is ignored, one needs to pass an empty vector to remove all the associations
    if ismissing(getproperty(updated_object, updated_property))
        return updated_object
    end

    orm_module = PostgresORM.get_orm(updated_object)

    counterpart_datatype = util_get_onetomany_counterparts(orm_module)[updated_property][:data_type]
    counterpart_property = util_get_onetomany_counterparts(orm_module)[updated_property][:property]
    action_on_remove = util_get_onetomany_counterparts(orm_module)[updated_property][:action_on_remove]

    # Update the elements in the vector to make sure that they all point to the
    #    updated object.
    #  This is for convenience so that it is sufficient to add an element to the
    #    vector to create the reference to the parent when we persist to the db.
    children = getproperty(updated_object, updated_property)

    for e in children
        setproperty!(e,
                     counterpart_property,
                     updated_object)
    end

    # Retrieve the current state of the database
    filter_object = counterpart_datatype()
    setproperty!(filter_object,counterpart_property,updated_object)
    previous_vector = retrieve_entity(filter_object,
                                      false, # do not retrieve complex properties
                                      dbconn
                                      )

    children = util_compare_and_sync_entities(previous_vector,
                                              children,
                                              counterpart_property,
                                              action_on_remove,
                                              dbconn;
                                              editor = editor)

    # @show children

    setproperty!(updated_object,
                 updated_property,
                 children)

end

# This function is useful when trying to update a property of type vector
# eg.
# country_deal_asso = CountryDealAsso(;deal = mydeal)
# old_countries_of_deals = retrieve_countrydeal_asso(country_deal_asso) # retrieve the previous state from the database
# util_compare_and_sync_entities(old_countries_of_deals, # previous_entities
#                                mydeal.countrydeal_assos, # new_entities
#                                dbconn;
#                                editor = superadmin)
function util_compare_and_sync_entities(previous_entities::Vector{<:IEntity},
                                        new_entities::Vector{<:IEntity},
                                        counterpart_property::Symbol,
                                        action_on_remove::CRUDType.CRUD, # either update of delete
                                        dbconn::Union{Missing,LibPQ.Connection};
                                        editor::Union{Missing, IEntity} = missing)


    if length(previous_entities) == 0 && length(new_entities) == 0
       return previous_entities
    end

    # Put the ids in a vector of dicts
    previous_ids = Vector{Dict{String,Any}}()
    for e in previous_entities
        push!(previous_ids, util_get_ids_cols_names_and_values(e,dbconn))
    end
    new_ids = Vector{Dict{String,<:Any}}()
    for e in new_entities
        push!(new_ids, util_get_ids_cols_names_and_values(e,dbconn))
    end

    # @info "previous_ids[$previous_ids]"
    # @info "new_ids[$new_ids]"

    # Retrieve the data_type
    if length(previous_entities) > 0
        data_type = typeof(previous_entities[1])
    else
        data_type = typeof(new_entities[1])
    end

    # ############################################################################## #
    # PART1. Identify the indexes of the entities for the different types of actions
    #   (i.e. remove the entity from the association, create and add an entity to
    #         the association, add an existing entity to the association)
    # ############################################################################## #

    # Loop over the previous_ids to see which ones need to be deleted/nulled
    indexes_of_entities_to_remove = [] # Refers to indexes in 'previous_entities'
    counter = 0
    ids_to_remove = Vector{Dict{String,<:Any}}()
    for previous_id in previous_ids
        counter+=1
        previous_id_still_here = false # Initialize
        for new_id in new_ids

            # If the new_id has a missing value we skip the comparison because
            #   1. It cannot be the previous_id (because it has a complete id)
            #   2. The comparison may return missing if none of the component of
            #         the dict is not missing
            if any(x -> ismissing(x), collect(values(new_id)))
                continue
            end

            if previous_id == new_id
                previous_id_still_here = true
                break
            end
        end
        # If we went through all the new ids without finding the id then it means
        #   that the entity is no longer part of the associations
        if !previous_id_still_here
            push!(ids_to_remove, previous_id)
            push!(indexes_of_entities_to_remove, counter)
        end
    end

    # Loop over the new_ids to see which ones need to be created/updated
    indexes_of_entities_to_create = [] # Refers to indexes in 'news_entities'
    indexes_of_entities_to_add = [] # Refers to indexes in 'news_entities'
    counter = 0
    for new_id in new_ids

        counter+=1

        # If one of the PK is null, create the entity
        if any(x -> ismissing(x), collect(values(new_id)))
            push!(indexes_of_entities_to_create,
                  counter)
            continue
        end

        # The id has already been added to the list of entities to be removed, skip
        if new_id in ids_to_remove
            continue
        end


        # If we cannot find an entity in the DB with this id, create it
        filter_object = data_type()
        for p in util_get_ids_props_names(filter_object)
            setproperty!(filter_object, p,
                         getproperty(new_entities[counter], p))
        end
        if length(retrieve_entity(filter_object,false, dbconn)) == 0 push!(indexes_of_entities_to_create,
                  counter)
            continue
        end

        # In other cases, update the target entity
        push!(indexes_of_entities_to_add,
              counter)
    end

    # ################################################################### #
    # PART2. Perform on the actions on the entities at the given indexes
    # ################################################################### #

    # Remove some associations
    for i in indexes_of_entities_to_remove
        filter_object = data_type()
        for p in util_get_ids_props_names(filter_object)
            setproperty!(filter_object,p,
                         getproperty(previous_entities[i],p))
        end
        # @info "Remove association to entity[$(util_prettify_id_values_as_str(filter_object))]"

        if action_on_remove == CRUDType.delete
            delete_entity(filter_object, dbconn; editor = editor)
        elseif action_on_remove == CRUDType.update
            # Retrieve the latest version of the database, we ignore the
            #   other possible changes
            removed_object = retrieve_entity(filter_object,
                                             false, # retrieve complex properties
                                             dbconn)[1]
            setproperty!(removed_object,counterpart_property,missing)
            update_entity!(removed_object,dbconn; editor = editor)

        else
            throw(DomainError("You can only choose 'delete' or 'update' when updating a vector property"))
        end

    end

    result = [] # Store the created/updated entities

    # Create new entities
    for i in indexes_of_entities_to_create
        filter_object = data_type()
        for p in util_get_ids_props_names(filter_object)
            setproperty!(filter_object,p,
                         getproperty(new_entities[i],p))
        end
        # @info "Create and add to association entity [$(util_prettify_id_values_as_str(filter_object))]"
        push!(result, create_entity!(new_entities[i],dbconn;creator = editor))
    end

    # Update existing entities
    for i in indexes_of_entities_to_add
        filter_object = data_type()
        for p in util_get_ids_props_names(filter_object)
            setproperty!(filter_object,p,
                         getproperty(new_entities[i],p))
        end
        # @info "Add to association existing entity [$(util_prettify_id_values_as_str(filter_object))]"
        push!(result, update_entity!(new_entities[i],dbconn;editor = editor))
    end

    return result

    # OLD Version with single PK (can be removed in a few months)
    # # Retrieve the id_property from one of the 2 vectors
    # if length(previous_entities) > 0
    #     id_property = PostgresORM.get_orm(previous_entities[1]).id_property
    #     data_type = typeof(previous_entities[1])
    # else
    #     id_property = PostgresORM.get_orm(new_entities[1]).id_property
    #     data_type = typeof(new_entities[1])
    # end
    #
    # # Get the ids (excluding the missing) of the previous and the new entities
    # # NOTE: the previous entities should all have an id
    # existings_ids_in_previous_entities =
    #     filter(x -> !ismissing(x),
    #            getproperty.(previous_entities,id_property))
    # existings_ids_in_new_entities =
    #    filter(x -> !ismissing(x),
    #           getproperty.(new_entities,id_property))
    #
    #
    # # The objects to delete are the ones whose ids do not exist in the
    # #    new list of entities
    # ids_to_remove = filter(x -> ! (x in existings_ids_in_new_entities),
    #                        existings_ids_in_previous_entities)
    #
    # # Delete the objects that must be deleted
    # for id in ids_to_remove
    #     filter_object = data_type()
    #     setproperty!(filter_object,id_property,id)
    #     if action_on_remove == CRUDType.delete
    #         delete_entity(filter_object, dbconn; editor = editor)
    #     elseif action_on_remove == CRUDType.update
    #         # Retrieve the latest version of the database, we ignore the
    #         #   other possible changes
    #         removed_object = retrieve_entity(filter_object,
    #                                          false, # retrieve complex properties
    #                                          dbconn)[1]
    #         setproperty!(removed_object,counterpart_property,missing)
    #         update_entity!(removed_object,dbconn; editor = editor)
    #
    #     else
    #         throw(DomainError("You can only choose 'delete' or 'update' when updating a vector property"))
    #     end
    # end
    #
    # # Create or update the other ones
    # result = []
    # for e in new_entities
    #     # If the entity has no id set it means it needs to be created
    #     if ismissing(getproperty(e,
    #                              id_property))
    #         push!(result, create_entity!(e,dbconn;creator = editor))
    #     else
    #         push!(result, update_entity!(e,dbconn;editor = editor))
    #     end
    # end
    #
    # return(result)

end


# query_string = "UPDATE appuser SET lastname = \S1, login = \$2
#                 WHERE id = \$3"
function update_entity!(updated_object::IEntity,
                       table_name::String,
                       columns_selection_and_mapping::Dict,
                       dbconn::LibPQ.Connection;
                       editor::Union{IEntity,Missing} = missing
                       )

    data_type = typeof(updated_object)
    orm_module = PostgresORM.get_orm(updated_object)

    query_string = "UPDATE " * table_name * " SET "

    props = util_get_entity_props_for_comparison(updated_object, dbconn)

    # Check if something has changed
    # NOTE: This is done for both deciding whether there is a need to do some
    #         changes to the database and for tracking the modifications
    previous_state_filter = data_type()
    idprops = util_get_ids_props_names(previous_state_filter)
    PostgresORMUtil.setpropertiesvalues!(previous_state_filter,
                                           idprops,
                                           PostgresORMUtil.getpropertiesvalues(updated_object,idprops))
    previous_state = retrieve_entity(previous_state_filter, orm_module,
                                     false, # we want the ids for comparison
                                     dbconn)

    if length(previous_state) == 0

        id_for_display = util_get_ids_cols_names_and_values(updated_object, dbconn) |>
            dict -> join(["$k: $v" for (k, v) in dict], ", ")

        throw(
            DomainError(
                "Unable to retrieve an object of type[$data_type] "
                *"with id[$id_for_display] "
                *"from the database. Remind that only existing objects can be updated."
            )
        )
    end

    previous_state = previous_state[1]

    previous_state_props = util_get_entity_props_for_comparison(previous_state,
                                                                dbconn)

    changes = diff_dict(previous_state_props, props)

    # If no changes were made, we just return the object
    if length(changes) == 0
        return updated_object
    end

    #
    # Enrich the updated object with the creator and creation time if needed
    #
    editor_property = util_get_editor_property(orm_module)
    if !ismissing(editor_property)

        # Only set the editor property if it is empty because the rest of the
        #  application may want to set it (eg. if importing data)
        if ismissing(getproperty(updated_object,editor_property))

            setproperty!(updated_object,
                         editor_property,
                         editor)
        # If the object has the creator property set, use it
        else
            editor = getproperty(updated_object,editor_property)
        end
    end
    update_time_property = util_get_update_time_property(orm_module)
    if !ismissing(update_time_property)
        setproperty!(updated_object,
                     update_time_property,
                     now(Dates.UTC))
    end

    # Compare versions if needed, by retrieving the current state of the object
    #   in the database
    if util_get_track_changes(orm_module)

         #
         # Create the modification entries
         #
         action_id = uuid4()

         # Create a string representation of the ID properties values.
         id_value_as_str = util_prettify_id_values_as_str(updated_object)

         # Get the editor id if any
         editor_id = if ismissing(editor)
           missing
         else
             util_prettify_id_values_as_str(editor)
         end

        for (k,v) in changes

             modif = Modification(entity_type =  string(data_type),
                                  entity_id = id_value_as_str,
                                  attrname = string(k),
                                  oldvalue = ismissing(v.old) ? missing : string(v.old),
                                  newvalue = ismissing(v.new) ? missing : string(v.new),
                                  appuser_id = editor_id,
                                  creation_time = now(Dates.UTC),
                                  action_type = CRUDType.update,
                                  action_id = action_id)
             create_entity!(modif,dbconn)
         end

     end # ENDOF if track_changes

    # Create the dictionnary of properties for insertion in the database
    props = util_get_entity_props_for_db_actions(updated_object,
                                                 dbconn,
                                                 true # include missing for updating columns to null
                                                 )
    properties_names = collect(keys(props))
    properties_values = collect(values(props))

    # The prepared statement has arguments corresponding to both the 'SET' clause
    #   and the 'WHERE' clause. Therefore we must increment the same counter as
    #   we loops over the properties that are updated and the ID properties.
    prepared_statement_args_counter = 0
    prepared_statement_args_values = Any[] # Holds the values of the prepared statement

    ids_cols_names = util_get_ids_cols_names(updated_object)

    # Add the 'SET' clause:
    # Loop over the properties that are updated
    # NOTE: we could remove the ID properties from this list but that's alright
    if length(props) > 0
        for (index,property_name) in enumerate(properties_names)


            # Add the restriction
            # eg. 'id = \$3'

            # NOTE: The mapping may not have the properties because some of the
            #          properties are the columns names of the complex objects
            #          which are added at runtime
            columnname = if haskey(columns_selection_and_mapping, property_name)
                            columns_selection_and_mapping[property_name]
                         else
                             property_name
                         end

             # If property is associated to an ID column, skip
             if string(columnname) in ids_cols_names
                 continue
             end

             prepared_statement_args_counter += 1
             # Add ',' if it's not the first property
             if prepared_statement_args_counter > 1
                 query_string *= ", "
             end

            query_string *= " $columnname = \$$prepared_statement_args_counter "

            # Store the new value of this property in the list of the values to
            #   be passed at execution of the prepared statement
            push!(prepared_statement_args_values,
                  props[Symbol(property_name)])
        end
    else
        # TODO throw_error
    end

    # Add the 'WHERE' clause:
    # Loop over the ID properties
    query_string *= " WHERE "
    where_clause_elts = Vector{String}()
    # An object can have several ID properties
    for id_property in util_get_ids_props_names(updated_object)
        # An ID property can have several columns (eg. when the property is a
        #   complex property that has several IDs)
        id_columnnames = tovector(columns_selection_and_mapping[id_property])
        for id_columnname in id_columnnames
            where_clause_elt =  "$id_columnname = \$$(prepared_statement_args_counter+=1)"
            push!(where_clause_elts, where_clause_elt)
            # If the ID property is a complex prop, then the value is stored
            #   under the name of the column name
            if isa(getproperty(updated_object, id_property),IEntity)
                push!(prepared_statement_args_values,
                      props[Symbol(id_columnname)])
            else
                push!(prepared_statement_args_values,
                      props[id_property])
            end

        end
    end
    query_string *= join(where_clause_elts, " AND ")

    query_string *= " RETURNING *";

    prepared_query = LibPQ.prepare(dbconn,
                           query_string)

    query_result = execute(prepared_query,
                           prepared_statement_args_values
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
                                           true, # retrieve_complex_props
                                           dbconn)

     util_overwrite_props!(result[1], # src entity
                           updated_object, # target entity
                           true # Ignore missing properties like all the
                                #    unmapped properties)
                           )

     return updated_object

end

function update_entity!(updated_object::IEntity,
                       orm_module::Module,
                       dbconn::LibPQ.Connection;
                       editor::Union{IEntity,Missing} = missing)
    update_entity!(updated_object,
                  util_get_table_with_schema_name(orm_module),
                  util_get_columns_selection_and_mapping(orm_module),
                  dbconn;
                  editor = editor)
end

function update_entity!(updated_object::IEntity,
                       dbconn::LibPQ.Connection;
                       editor::Union{IEntity,Missing} = missing
                       )
    update_entity!(updated_object,
                  PostgresORM.get_orm(updated_object),
                  dbconn;
                  editor = editor)
end
