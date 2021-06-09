using Pkg
Pkg.activate(".")
# Also need to execute in the pkg applcation the following command:
# `develop TestApp`
# This is because the followign command does not work:
# Pkg.develop(path = "/home/vlaugier/CODE/PostgresORM/TestApp")
using Revise

using Test

# push!(LOAD_PATH, "/home/vlaugier/CODE/PostgresORM.jl/test/test-apps/Pagila/src/Pagila.jl/")

include("../src/Pagila.jl")
include("../src/using-Pagila.jl")

using Main.Pagila.Model

dbconn = Main.Pagila.PagilaUtil.openDBConn()

# Retrieve and update an actor
actorFilter = Pagila.Model.Actor(last_name = "GUINESS")
actor = PostgresORM.Controller.retrieve_entity(actorFilter,false,dbconn)[1]
actor.last_update = now()
PostgresORM.Controller.update_entity!(actor,dbconn)

# Retrieve and update a film
filmFilter = Pagila.Model.Film(title = "ACADEMY DINOSAUR")
filmResult = PostgresORM.Controller.retrieve_entity(filmFilter,false,dbconn)[1]
filmResult.title = " ACADEMY DINOSAUR"
filmResult.title *= " TOTOde"
PostgresORM.Controller.update_entity!(filmResult,dbconn)

string(getpropertiesvalues(filmResult,[:film_id,:title]))

# Update a FilmActorAsso
film = PostgresORM.Controller.retrieve_entity(Film(film_id = 1),false,dbconn)[1]
filmActorAssoFilter = Pagila.Model.FilmActorAsso(film = film)
filmActorAssoResult = PostgresORM.Controller.retrieve_entity(filmActorAssoFilter,false,dbconn)
filmActorAssoResult = filmActorAssoResult[1]
filmActorAssoResult.last_update = now()
PostgresORM.Controller.update_entity!(filmActorAssoResult,dbconn)

# Create new FilmActorAsso
film = PostgresORM.Controller.retrieve_entity(Film(film_id = 1),false,dbconn)[1]
actorForNewAsso = PostgresORM.Controller.retrieve_entity(Actor(actor_id = 100),false,dbconn)[1]
newfilmActorAsso = Pagila.Model.FilmActorAsso(film = film, actor = actorForNewAsso)
PostgresORM.Controller.create_entity!(newfilmActorAsso,dbconn)

# Delete FilmActorAsso
actor = PostgresORM.Controller.retrieve_entity(Actor(actor_id = 100),false,dbconn)[1]
filmActorAsso = PostgresORM.Controller.retrieve_entity(
                    Pagila.Model.FilmActorAsso(film = film, actor = actor),false,
                    dbconn)[1]
PostgresORM.Controller.delete_entity(filmActorAsso,dbconn)

PagilaUtil.closeDBConn(dbconn)
