mutable struct Film <: IFilm

  film_id::Union{Missing,Int32}
  title::Union{Missing,String}
  description::Union{Missing,String}
  release_year::Union{Missing,Int32}
  language_id::Union{Missing,Int16}
  original_language_id::Union{Missing,Int16}
  rental_duration::Union{Missing,Int16}
  rental_rate::Union{Missing,Float64}
  length::Union{Missing,Int16}
  replacement_cost::Union{Missing,Float64}
  rating::Union{Missing,String}
  last_update::Union{Missing,DateTime}
  special_features::Union{Missing,Vector{String}}

  actor_assos::Union{Missing,Vector{IFilmActorAsso}}

  Film(args::NamedTuple) = Film(;args...)
  Film(;
        film_id = missing,
        title = missing,
        description = missing,
        release_year = missing,
        language_id = missing,
        original_language_id = missing,
        rental_duration = missing,
        rental_rate = missing,
        length = missing,
        replacement_cost = missing,
        rating = missing,
        last_update = missing,
        special_features = missing,
        actor_assos = missing,
 ) = (
            x = new(missing, missing, missing, missing, missing,
                    missing, missing, missing, missing, missing,
                    missing, missing, missing, missing);
            x.film_id = film_id;
            x.title = title;
            x.description = description;
            x.release_year = release_year;
            x.language_id = language_id;
            x.original_language_id = original_language_id;
            x.rental_duration = rental_duration;
            x.rental_rate = rental_rate;
            x.length = length;
            x.replacement_cost = replacement_cost;
            x.rating = rating;
            x.last_update = last_update;
            x.special_features = special_features;
            x.actor_assos = actor_assos;
            return x
            )

end
