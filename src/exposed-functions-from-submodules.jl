# CREATE
function create_entity!(new_object::IEntity,
                       dbconn::LibPQ.Connection;
                       creator::Union{IAppUser,Missing} = missing)

   Controller.create_entity!(new_object,
                             dbconn;
                             creator = creator)
end

function create_in_bulk_using_copy(entities::Vector{T},
                                   dbconn::LibPQ.Connection) where T <: IEntity

   Controller.create_in_bulk_using_copy(entities,
                                        dbconn)
end

# RETRIEVE
"""
    retrieve_entity(filter_object::IEntity,
                    retrieve_complex_props::Bool,
                    dbconn::LibPQ.Connection)

Retrieves a vector or T instances that match the filter.
If there is no match, it returns an empty vector.
"""
function retrieve_entity(filter_object::IEntity,
                         retrieve_complex_props::Bool,
                         dbconn::LibPQ.Connection)

     Controller.retrieve_entity(filter_object,
                               retrieve_complex_props,
                               dbconn)
end

"""
    retrieve_one_entity(filter_object::T,
                        retrieve_complex_props::Bool,
                        dbconn::LibPQ.Connection)

Retrieves an instance ot T that matches the filter.
If there is no match then the function returns missing.
If there are more than one match, an error is thrown.
If `retrieve_complex_props` is true then a complex prop (i.e. a property of
type IEntity) is fully loaded using an additional query to the database ;
if not, an instance of IEntity is simply created using the values of the foreign
key
"""
function retrieve_one_entity(filter_object::T,
                             retrieve_complex_props::Bool,
                             dbconn::LibPQ.Connection) where T <: IEntity
     Controller.retrieve_one_entity(filter_object,
                                     retrieve_complex_props,
                                     dbconn)
end

# UPDATE
function update_entity!(updated_object::IEntity,
                       dbconn::LibPQ.Connection;
                       editor::Union{IAppUser,Missing} = missing
                       )
    Controller.update_entity!(updated_object,
                              dbconn;
                              editor = dbconn
                              )
end

function update_vector_property!(updated_object::IEntity,
                                 updated_property::Symbol,
                                 dbconn::Union{Missing, LibPQ.Connection};
                                 editor::Union{Missing, IAppUser} = missing)

      Controller.update_vector_property!(updated_object,
                                        updated_property,
                                        dbconn;
                                        editor = editor)

end

# DELETE
function delete_entity(deleted_object::IEntity,
                       dbconn::LibPQ.Connection;
                       editor::Union{IAppUser,Missing} = missing
                       )
    Controller.delete_entity(deleted_object,
                             dbconn;
                             editor = editor
                             )
end

function delete_entity_alike(filter_object::IEntity,
                       dbconn::LibPQ.Connection;
                       editor::Union{IAppUser,Missing} = missing
                       )
    Controller.delete_entity_alike(filter_object,
                                   dbconn;
                                   editor = editor
                                   )
end
