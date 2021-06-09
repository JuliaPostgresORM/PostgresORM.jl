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

using PostgresORM
using PostgresORM.Tool
using LibPQ


out_dir = (@__DIR__) * "/out"
dbconn = PagilaUtil.openDBConnAndBeginTransaction()

PostgresORM.Tool.generate_julia_struct_from_table(dbconn,
                             "public",
                             "actor",
                             "Actor",
                             (out_dir * "/Actor.jl"),
                             (out_dir * "/ActorORM.jl")
                            ;camelcase_is_default = false
                            )

PostgresORM.Tool.generate_julia_struct_from_table(dbconn,
                             "public",
                             "film",
                             "Film",
                             (out_dir * "/Film.jl"),
                             (out_dir * "/FilmORM.jl")
                            ;ignored_columns = ["fulltext"],
                            camelcase_is_default = false
                            )

PostgresORM.Tool.generate_julia_struct_from_table(dbconn,
                             "public",
                             "film_actor",
                             "FilmActorAsso",
                             (out_dir * "/FilmActorAsso.jl"),
                             (out_dir * "/FilmActorAssoORM.jl")
                            ;camelcase_is_default = false
                            )

PagilaUtil.closeDBConn(dbconn)
