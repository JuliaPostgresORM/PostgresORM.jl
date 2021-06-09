data_type = Actor
PostgresORM.get_orm(x::Actor) = return(ActorORM)
get_table_name() = "public.actor"
const columns_selection_and_mapping =
  Dict(
    :actor_id => "actor_id",
    :first_name => "first_name",
    :last_name => "last_name",
    :last_update => "last_update"
  )
get_id_props() = return [id_property]

const id_property = :actor_id

# A dictionnary of mapping between fields symbols and overriding types
#   Left hanside is the field symbol ; right hand side is the type override
const types_override = Dict()

const track_changes = true
