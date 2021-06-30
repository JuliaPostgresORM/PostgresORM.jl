include("runtests-prerequisite.jl")

abstract type IMyFantasticStruct <: PostgresORM.IEntity end
abstract type IMyGreatMovie <: PostgresORM.IEntity end

mutable struct MyGreatMovie <: IMyGreatMovie

  title::Union{Missing,String}
  year::Union{Missing,Int32}

  MyGreatMovie(args::NamedTuple) = MyGreatMovie(;args...)
  MyGreatMovie(;title = missing,
           year = missing,) = (
            x = new(missing, missing);
            x.title = title;
            x.year = year;
            return x
            )
end

mutable struct MyFantasticStruct <: IMyFantasticStruct

  id::Union{Missing,Int32}
  first_name::Union{Missing,String}
  favorite_movie::Union{Missing, IMyGreatMovie}

  MyFantasticStruct(args::NamedTuple) = MyFantasticStruct(;args...)
  MyFantasticStruct(;
        id = missing,
        first_name = missing,
        favorite_movie = missing,
 ) = (
            x = new(missing, missing, missing);
            x.id = id;
            x.first_name = first_name;
            x.favorite_movie = favorite_movie;
            return x
            )

end

module MyFantasticStructORM
    data_type = Main.MyFantasticStruct
    Main.PostgresORM.get_orm(x::Main.MyFantasticStruct) = return(MyFantasticStructORM)
    get_table_name() = "public.my_new_struct"
    const columns_selection_and_mapping =
      Dict(
         :id => "id",
         :first_name => "first_name",
         :favorite_movie => ["favorite_movie_title","favorite_movie_year"]
      )
    get_id_props() = return [:id]


    # A dictionnary of mapping between fields symbols and overriding types
    #   Left hanside is the field symbol ; right hand side is the type override
    const types_override = Dict(:favorite_movie => Main.MyGreatMovie)

    const track_changes = false
end


@testset "Test `util_get_property_real_type`" begin
  @test PostgresORM.Controller.util_get_property_real_type(MyFantasticStruct, :favorite_movie) == Main.MyGreatMovie
  @test PostgresORM.Controller.util_get_property_real_type(MyFantasticStruct, :first_name) == String
end
