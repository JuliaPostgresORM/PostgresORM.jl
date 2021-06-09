data_type = Film
PostgresORM.get_orm(x::Film) = return(FilmORM)
get_table_name() = "public.film"
const columns_selection_and_mapping =
  Dict(
    :film_id => "film_id",
    :title => ["title"],
    :description => "description",
    :release_year => "release_year",
    :language_id => "language_id",
    :original_language_id => "original_language_id",
    :rental_duration => "rental_duration",
    :rental_rate => "rental_rate",
    :length => "length",
    :replacement_cost => "replacement_cost",
    :rating => "rating",
    :last_update => "last_update",
    :special_features => "special_features"
  )

const id_property = [:film_id,:release_year]

# A dictionnary of mapping between fields symbols and overriding types
#   Left hanside is the field symbol ; right hand side is the type override
const types_override = Dict()

const track_changes = true

using PostgresORM.Model.Enums.CRUDType
const onetomany_counterparts =
    Dict(:actor_assos => (data_type = FilmActorAsso,
                                 property = :film,
                                 action_on_remove = CRUDType.delete))
