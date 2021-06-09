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
