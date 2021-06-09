module Test_util_get_ids_cols_names

    using PostgresORM

    mutable struct MySuperMovie <: PostgresORM.Model.IEntity

      title::Union{Missing,String}
      year::Union{Missing,Int32}

      MySuperMovie(args::NamedTuple) = MySuperMovie(;args...)
      MySuperMovie(;title = missing,
               year = missing,) = (
                x = new(missing, missing);
                x.title = title;
                x.year = year;
                return x
                )
    end

    mutable struct MyNewStruct <: PostgresORM.Model.IEntity

      actor_id::Union{Missing,Int32}
      first_name::Union{Missing,String}
      favorite_movie::Union{Missing, MySuperMovie}

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


# ############################################### #
# TEST 1: the ORM has its function 'get_id_props()' #
# ############################################### #
module MyNewStructORM
    data_type = Main.Test_util_get_ids_cols_names.MyNewStruct
    Main.PostgresORM.get_orm(x::Main.Test_util_get_ids_cols_names.MyNewStruct) = return(MyNewStructORM)
    get_table_name() = "public.my_new_struct"
    const columns_selection_and_mapping =
      Dict(
         :actor_id => "actor_id",
         :first_name => "first_name",
         :favorite_movie => ["favorite_movie_id"],
         :favorite_movies => ["favorite_movie1_id","favorite_movie2_id"]
      )
    get_id_props() = return [:actor_id,:first_name,:favorite_movie, :favorite_movies]

    # A dictionnary of mapping between fields symbols and overriding types
    #   Left hanside is the field symbol ; right hand side is the type override
    const types_override = Dict()

    const track_changes = false
end

@testset "Test `util_get_ids_cols_names(o::IEntity)` with a ORM with a function `get_id_props()``" begin
    myNewStruct = Test_util_get_ids_cols_names.MyNewStruct(actor_id = 3,first_name="toto")
    PostgresORM.get_orm(myNewStruct)
    @test PostgresORM.Controller.util_get_ids_cols_names(myNewStruct) ==
      ["actor_id", "first_name", "favorite_movie_id", "favorite_movie1_id", "favorite_movie2_id"]
end
