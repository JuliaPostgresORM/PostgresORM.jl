include("./runtests-prerequisite-Pagila.jl")

using Main.Pagila.Model

dbconn = Main.Pagila.PagilaUtil.openDBConn()


film = PostgresORM.Controller.retrieve_entity(Film(film_id = 1, release_year = 2006),false,dbconn)[1]
filmActorAssoFilter = Pagila.Model.FilmActorAsso(film = film)
filmActorAssoResult = PostgresORM.Controller.retrieve_entity(filmActorAssoFilter,false,dbconn)
kept = filmActorAssoResult[1:3]
leftout = filmActorAssoResult[6:11]
newAsso = Pagila.Model.FilmActorAsso(
            actor = PostgresORM.Controller.retrieve_entity(
                      Actor(actor_id = 51),false,dbconn)[1]
            )
updated_assos = [kept...,newAsso]
# getproperty.(getproperty.(kept,:actor),:actor_id)
# getproperty.(getproperty.(leftout,:actor),:actor_id)
film.actor_assos = updated_assos

PostgresORM.Controller.update_vector_property!(film,:actor_assos,dbconn)

PagilaUtil.closeDBConn(dbconn)
