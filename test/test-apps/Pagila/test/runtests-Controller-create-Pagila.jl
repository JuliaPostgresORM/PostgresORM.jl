include("./runtests-prerequisite-Pagila.jl")

using Main.Pagila.Model
using Dates
DateTime("2020-09-12T13:54:30")

dbconn = Main.Pagila.PagilaUtil.openDBConn()

actor1 = Actor(first_name = "Alec",
               last_name = "Baldwin",
               last_update = DateTime("2020-09-12T13:54:30"))
actor2 = Actor(first_name = "Franck",
              last_name = "Baldwin",
              last_update = DateTime("2020-09-12T13:54:30"))
actors = [actor1, actor2]

PostgresORM.Controller.create_in_bulk_using_copy(actors,dbconn)

PagilaUtil.closeDBConn(dbconn)
