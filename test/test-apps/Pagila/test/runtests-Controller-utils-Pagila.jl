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

film = PostgresORM.Controller.retrieve_entity(Film(film_id = 1),false,dbconn)[1]
filmActorAssoFilter = Pagila.Model.FilmActorAsso(film = film)
filmActorAssoResult = PostgresORM.Controller.retrieve_entity(filmActorAssoFilter,false,dbconn)
filmActorAssoResult = filmActorAssoResult[1]

PostgresORM.Controller.util_get_cols_names_and_values(
    filmActorAssoResult,dbconn)

PostgresORM.Controller.util_get_ids_cols_names_and_values(
    filmActorAssoResult,dbconn)

PagilaUtil.closeDBConn(dbconn)
