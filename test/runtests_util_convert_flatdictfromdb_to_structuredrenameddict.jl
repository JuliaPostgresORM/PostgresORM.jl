include("runtests-prerequisite.jl")

mutable struct MyMovie <: PostgresORM.IEntity

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


mutable struct MyGreatStruct <: PostgresORM.IEntity

  id::Union{Missing,Int32}
  first_name::Union{Missing,String}
  favorite_movie::Union{Missing, MyMovie}

  MyGreatStruct(args::NamedTuple) = MyGreatStruct(;args...)
  MyGreatStruct(;
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

module MyGreatStructORM
    data_type = Main.MyGreatStruct
    Main.PostgresORM.get_orm(x::Main.MyGreatStruct) = return(MyGreatStructORM)
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
    const types_override = Dict()

    const track_changes = false
end

module MyMovieORM
    data_type = Main.MyMovie
    Main.PostgresORM.get_orm(x::Main.MyMovie) = return(MyMovieORM)
    get_table_name() = "public.my_movie"
    const columns_selection_and_mapping =
      Dict(
         :title => "title",
         :year => "year"
      )
    get_id_props() = return [:title,:year]


    # A dictionnary of mapping between fields symbols and overriding types
    #   Left hanside is the field symbol ; right hand side is the type override
    const types_override = Dict()

    const track_changes = false
end

@testset "Test `util_convert_flatdictfromdb_to_structuredrenameddict`" begin

    flatdict = Dict(:id => 1,
                    :first_name=> "Vincent",
                    :favorite_movie_title => "The Godfather",
                    :favorite_movie_year => 1972)


    PostgresORM.Controller.util_convert_flatdictfromdb_to_structuredrenameddict(flatdict,
                                                         MyGreatStruct)
end
