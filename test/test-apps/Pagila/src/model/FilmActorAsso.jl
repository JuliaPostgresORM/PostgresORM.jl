mutable struct FilmActorAsso <: IFilmActorAsso

  actor::Union{Missing,IActor}
  film::Union{Missing,IFilm}
  last_update::Union{Missing,DateTime}

  FilmActorAsso(args::NamedTuple) = FilmActorAsso(;args...)
  FilmActorAsso(;
        actor = missing,
        film = missing,
        last_update = missing,
 ) = (
            x = new(missing, missing, missing);
            x.actor = actor;
            x.film = film;
            x.last_update = last_update;
            return x
            )

end
