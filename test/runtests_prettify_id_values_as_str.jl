include("runtests-prerequisite.jl")

module Test_util_prettify_id_values_as_str

    using PostgresORM

    mutable struct MyMovie <: PostgresORM.IEntity

      title::Union{Missing,String}
      year::Union{Missing,Int32}
      description::Union{Missing,String}

      MyMovie(args::NamedTuple) = MyMovie(;args...)
      MyMovie(;title = missing,
               year = missing,
               description = missing) = (
                x = new(missing, missing);
                x.title = title;
                x.year = year;
                x.description = description;
                return x
                )
    end

    mutable struct MyNewStruct <: PostgresORM.IEntity

      actor_id::Union{Missing,Int32}
      first_name::Union{Missing,String}
      favorite_movie::Union{Missing, MyMovie}

      MyNewStruct(args::NamedTuple) = MyNewStruct(;args...)
      MyNewStruct(;
            actor_id = missing,
            first_name = missing,
            favorite_movie = missing,
     ) = (
                x = new(missing, missing, missing);
                x.actor_id = actor_id;
                x.first_name = first_name;
                x.favorite_movie = favorite_movie;
                return x
                )

    end
end # module

module MyNewStructORM
    data_type = Main.Test_util_prettify_id_values_as_str.MyNewStruct
    Main.PostgresORM.get_orm(x::Main.Test_util_prettify_id_values_as_str.MyNewStruct) = return(MyNewStructORM)
    get_table_name() = "public.my_new_struct"
    const columns_selection_and_mapping =
      Dict(
         :actor_id => "actor_id",
         :first_name => "first_name",
         :favorite_movie => ["favorite_movie_id"]
      )
    get_id_props() = return [:actor_id,:first_name,:favorite_movie]

    # A dictionnary of mapping between fields symbols and overriding types
    #   Left hanside is the field symbol ; right hand side is the type override
    const types_override = Dict()

    const track_changes = false
end

module MyMovieORM
    data_type = Main.Test_util_prettify_id_values_as_str.MyMovie
    Main.PostgresORM.get_orm(x::Main.Test_util_prettify_id_values_as_str.MyMovie) = return(MyMovieORM)
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


@testset "Test `util_prettify_id_values_as_str(values::Vector{<:Any})`" begin

    mymovie =
        Test_util_prettify_id_values_as_str.MyMovie(title = "movie1",
                                                         year = 2007,
                                                         description = "description1")

    object = Test_util_prettify_id_values_as_str.MyNewStruct(actor_id = 2000,
                                                             first_name = "bob",
                                                             favorite_movie = mymovie)

    PostgresORM.Controller.util_prettify_id_values_as_str(object)


end
