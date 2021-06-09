abstract type IMyNewStruct <: PostgresORM.Model.IEntity end
abstract type IMyMovie <: PostgresORM.Model.IEntity end

mutable struct MyMovie <: IMyMovie

  title::Union{Missing,String}
  year::Union{Missing,Int32}

  MyMovie(args::NamedTuple) = MyMovie(;args...)
  MyMovie(;title = missing,
           year = missing,) = (
            x = new(missing, missing);
            x.title = title;
            x.year = year;
            return x
            )
end

mutable struct MyNewStruct <: IMyNewStruct

  id::Union{Missing,Int32}
  first_name::Union{Missing,String}
  favorite_movie::Union{Missing, IMyMovie}

  MyNewStruct(args::NamedTuple) = MyNewStruct(;args...)
  MyNewStruct(;
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

module MyNewStructORM
    data_type = Main.MyNewStruct
    Main.PostgresORM.get_orm(x::Main.MyNewStruct) = return(MyNewStructORM)
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
    const types_override = Dict(:favorite_movie => Main.MyMovie)

    const track_changes = false
end


@testset "Test `util_get_property_real_type`" begin
  @test PostgresORM.Controller.util_get_property_real_type(MyNewStruct, :favorite_movie) == Main.MyMovie
  @test PostgresORM.Controller.util_get_property_real_type(MyNewStruct, :first_name) == String
end
