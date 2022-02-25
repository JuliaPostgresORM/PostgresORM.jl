include("../runtests-prerequisite.jl")
using Serialization

@testset "Test Tool.get_typescript_type(_field::Dict)`" begin
    object_model = Serialization.deserialize("test/assets/object_model.jld")
    object_model = Serialization.deserialize("/home/vlaugier/CODE/forensic/medilegist/Medilegist.jl/dev/PostgresORM/test/assets/object_model.jld")

    onetomany_field = filter(x-> x[:is_onetomany], object_model[:fields])[1]
    PostgresORM.Tool.get_typescript_type(onetomany_field)

    enum_field = filter(x-> x[:is_enum], object_model[:fields])[1]
    PostgresORM.Tool.get_typescript_type(enum_field)


    byte_field = filter(x-> x[:field_type] == "Vector{UInt8}", object_model[:fields])[1]
    PostgresORM.Tool.get_typescript_type(byte_field)

end

@testset "Test Tool.get_typescript_type_of_elt_type(julia_elt_type::String)`" begin
    PostgresORM.Tool.get_typescript_type_of_elt_type("Bool") == "boolean"
    PostgresORM.Tool.get_typescript_type_of_elt_type("Model.Mammal") == "Mammal"
    PostgresORM.Tool.get_typescript_type_of_elt_type("Model.Exam") == "Exam"
end

4
