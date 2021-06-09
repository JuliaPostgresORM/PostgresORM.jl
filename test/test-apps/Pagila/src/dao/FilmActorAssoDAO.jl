data_type = FilmActorAsso
PostgresORM.get_orm(x::FilmActorAsso) = return(FilmActorAssoORM)
get_table_name() = "public.film_actor"
const columns_selection_and_mapping =
  Dict(
    :actor => "actor_id",
    :film => ["film_id","film_release_year"],
    :last_update => "last_update"
  )
get_id_props() = return [:actor, :film]

# A dictionnary of mapping between fields symbols and overriding types
#   Left hanside is the field symbol ; right hand side is the type override
const types_override = Dict(:actor => Actor, :film => Film)

const track_changes = true
