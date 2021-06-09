using Pkg
Pkg.activate(".")

using Revise

using Test

using PostgresORM.Tool
using LibPQ


@testset "Test Tool.jl - function `generateJuliaStructFromTable()`" begin

    out_dir = (@__DIR__) * "/out"

    dbconn = LibPQ.Connection("dbname=oqs_nancy user=oqs_nancy"; throw_error=true)

    cols = generateJuliaStructFromTable(dbconn,
                                 "sae",
                                 "horaire",
                                 "SAEHoraire",
                                 (out_dir * "/SAEHoraire.jl"),
                                 (out_dir * "/SAEHoraireORM.jl")
                                ;camelizeByDefault = false,
                                 exceptionsToDefault = ["journee_exploitation"]
                                 )

     generateJuliaStructFromTable(dbconn,
                                  "sae",
                                  "ref_course",
                                  "SAERefCourse",
                                  (out_dir * "/SAERefCourse.jl"),
                                  (out_dir * "/SAERefCourseORM.jl")
                                 ;camelizeByDefault = false,
                                  # exceptionsToDefault = ["journee_exploitation"]
                                  )

    "id" in cols[:,:column_name]

    "all" == ["dede","dede"]

    cols[1,:]
    cols[:,:column_type]
    names(cols)
    cols[:column_type]

    join(cols.column_name," = missing,\n")
    nrow(cols)
    join(repeat(["missing"],nrow(cols)),", ")

    join(string.("x.",cols.column_name," = " , cols.column_name),", \n")

    indent
    for c in eachrow(cols)
        @info c.column_type
        @info c[:column_type]
    end

end
