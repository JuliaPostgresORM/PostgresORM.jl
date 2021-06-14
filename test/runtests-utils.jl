include("runtests-prerequisite.jl")


@testset "Test utils.jl - function `string2enum()`" begin
    @enum Fruit apple=10 orange=20 kiwi=30
    @test string2enum(Fruit, "orange") == orange
end

@testset "Test utils.jl - function `int2enum()`" begin
    @enum Fruit apple=10 orange=20 kiwi=30
    @test int2enum(Fruit, 20) == orange
end


@testset "Test utils.jl - function `dict2vectoroftuples()`" begin
    props = Dict(:a => 1, :b => missing, :c => "de", "d" => 9)
    PostgresORMUtil.dict2vectoroftuples(props)
end

@testset "Test utils.jl - function `vectoroftuples2dict()`" begin
    vectoroftuples = [(:a, 1),(:b, missing),(:c, "de"),("d", 9)]
    PostgresORMUtil.vectoroftuples2dict(vectoroftuples)
end

@testset "Test utils.jl - function `dictstringkeys2symbol()`" begin
    @test dictstringkeys2symbol(Dict("company" => String,
                       "canpost" => Bool)) == Dict(:company => String,
                                          :canpost => Bool)
end

@testset "Test utils.jl - function `dict2namedtuple()`" begin
    @test dict2namedtuple(Dict(:company => String,
                       :canpost => Bool)) == (company = String, canpost = Bool)
end

@testset "Test utils.jl - function `namedtuple2dict()`" begin
    @test namedtuple2dict((company = String,
                           canpost = Bool)) == Dict(:company => String,
                                              :canpost => Bool)
end

@testset "Test utils.jl - function `tovector()`" begin
    @test tovector(("1","2")) == ["1","2"]
    @test tovector(("1")) == ["1"]
    @test_throws ArgumentError tovector((a = "1", b= "2"))
    @test tovector(:toto) == [:toto]
    @test tovector("toto";elementstype = Symbol) == [:toto]
    @test tovector((:toto,:tata);elementstype = Symbol) == [:toto,:tata]
    @test tovector(:toto;elementstype = Symbol) == [:toto]
end


@testset "Test utils.jl - function `get_nonmissing_typeof_uniontype()`" begin
    @test get_nonmissing_typeof_uniontype(Union{String,Missing}) == String
    @test get_nonmissing_typeof_uniontype(Union{Missing,String,Nothing}) == String
    @test get_nonmissing_typeof_uniontype(Union{Bool,Missing,Nothing}) == Bool
    @test get_nonmissing_typeof_uniontype(Union{Vector{String},Missing,Nothing}) == Vector{String}
end

@testset "Test utils.jl - function `dataframe2vector_of_namedtuples()`" begin

    df = DataFrame(SepalLength = [5.1,3],
                    SepalWidth = [3.5,4],
                    Species = ["setosa","versicolor"])

    df = @from i in df begin
         @select {i.SepalLength,i.SepalWidth,i.Species}
         @collect DataFrame
    end

    result = dataframe2vector_of_namedtuples(df)
    @test result[1] == (SepalLength = 5.1, SepalWidth = 3.5, Species = "setosa")

end

@testset "Test utils.jl - function `diff_dict()`" begin

    old_dict = Dict("attr1" => 4,"attr2" => 2, "attr4" => 8, "attr5" => missing, "attr6" => missing)
    new_dict = Dict("attr1" => 5,"attr3" => 6, "attr4" => missing, "attr5" => 7, "attr6" => missing)

    (ismissing(old_dict["attr6"])  == ismissing(new_dict["attr6"]))

    diff_result  = diff_dict(old_dict, new_dict)

    @test diff_result["attr1"] == (old = 4, new = 5)
    @test diff_result["attr2"].old == 2
    @test ismissing(diff_result["attr2"].new)
    @test ismissing(diff_result["attr3"].old)
    @test diff_result["attr3"].new == 6

end

@testset "Test utils.jl - function `string2zoneddatetime`" begin
    PostgresORMUtil.string2zoneddatetime("2019-09-03T11:00:00.000Z")
end

@testset "Test utils.jl - function `postgresql_string_array_2_string_vector`" begin
    str = "{\"Deleted. 3 Scenes (a,2,e)\",\"Behind the Scenes\",\"\"}"
    res = PostgresORMUtil.postgresql_string_array_2_string_vector(str)
    @test res == ["Deleted. 3 Scenes (a,2,e)","Behind the Scenes",""]

    str = "{aa,\"Deleted. 3 Scenes (a,2,e)\",bb,\"Behind the Scenes\",\"\",cc}"
    res = PostgresORMUtil.postgresql_string_array_2_string_vector(str)
    @test res == ["aa","Deleted. 3 Scenes (a,2,e)","bb","Behind the Scenes","","cc"]

    str = "{aa,bb,cc,dd}"
    res = PostgresORMUtil.postgresql_string_array_2_string_vector(str)
    @test res == ["aa","bb","cc","dd"]

    # This one fails
    str = "{\"bla bla\",bb,cc}"
    res = PostgresORMUtil.postgresql_string_array_2_string_vector(str)
    @test res == ["bla bla","bb","cc"]

end


@testset "Test utils.jl - function `getpropertiesvalues`" begin

    mutable struct MyNewStruct <: PostgresORM.IEntity

      actor_id::Union{Missing,Int32}
      first_name::Union{Missing,String}

      MyNewStruct(args::NamedTuple) = MyNewStruct(;args...)
      MyNewStruct(;
            actor_id = missing,
            first_name = missing,
     ) = (
                x = new(missing, missing);
                x.actor_id = actor_id;
                x.first_name = first_name;
                return x
                )
    end

    myNewStruct = MyNewStruct(actor_id = 3,first_name="toto")

    @test PostgresORMUtil.getpropertiesvalues(myNewStruct,[:actor_id,:first_name]) == [3,"toto"]
end



@testset "Test utils.jl - function `setpropertiesvalues`" begin

    mutable struct MyNewStruct <: PostgresORM.IEntity

      actor_id::Union{Missing,Int32}
      first_name::Union{Missing,String}

      MyNewStruct(args::NamedTuple) = MyNewStruct(;args...)
      MyNewStruct(;
            actor_id = missing,
            first_name = missing,
     ) = (
                x = new(missing, missing);
                x.actor_id = actor_id;
                x.first_name = first_name;
                return x
                )
    end

    myNewStruct = MyNewStruct(actor_id = 3,first_name="toto")
    PostgresORMUtil.setpropertiesvalues!(myNewStruct,[:actor_id,:first_name],[4,"tata"])
    @test myNewStruct.actor_id == 4
    @test myNewStruct.first_name == "tata"
end

@testset "Test utils.jl - function `remove_spaces_and_split`" begin
    @test PostgresORMUtil.remove_spaces_and_split("rfr ") == ["rfr"]
    PostgresORMUtil.remove_spaces_and_split("  rfr, ded") == ["rfr","ded"]
end
