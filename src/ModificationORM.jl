data_type = Modification
PostgresORM.get_orm(x::Modification) = return(ModificationORM)
gettablename() = "modification"
get_table_name() = gettablename()
get_schema_name() = "public"
# The format of the mapping is: `property name = "column name"`

const columns_selection_and_mapping = Dict(:id => "id",
                                     :entity_type => "entity_type",
                                     :entity_id => "entity_id",
                                     :attrname => "attrname",
                                     :oldvalue => "oldvalue",
                                     :newvalue => "newvalue",
                                     :appuser_id => "user_id",
                                     :action_id => "action_id",
                                     :action_type => "action_type",
                                     :creation_time => "creation_time")

const id_property = :id

# A dictionnary of mapping between fields symbols and overriding types
#   Left hanside is the field symbol ; right hand side is the type override
types_override = Dict()

const track_changes = false
#
# function create_modification(new_object::Modification)
#     dbconn = opendbconn()
#     result = create_entity!(new_object,
#                            dbconn)
#     closedbconn(dbconn)
#     return result
# end
#
# function update_modification(new_object::Modification)
#     dbconn = opendbconn()
#     result = update_entity!(new_object,
#                            dbconn)
#     closedbconn(dbconn)
#     return result
# end
#
# function retrieve_modification(filter_object::Union{Modification,Missing};
#                           include_users = false)
#     dbconn = opendbconn()
#
#     result = retrieve_entity(filter_object,
#                              data_type,
#                              table_name,
#                              columns_selection_and_mapping,
#                              true, # retrieve_complex_props
#                              dbconn)
#
#
#     closedbconn(dbconn)
#     return result
# end
#
# function retrieve_modification()
#     retrieve_modification(missing)
# end
