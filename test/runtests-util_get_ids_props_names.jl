
mutable struct MyNewStruct <: PostgresORM.Model.IEntity

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



# ############################################### #
# TEST 1: the ORM has its function 'get_id_props()' #
# ############################################### #
module MyNewStructORM
    data_type = Main.MyNewStruct
    Main.PostgresORM.get_orm(x::Main.MyNewStruct) = return(MyNewStructORM)
    get_table_name() = "public.my_new_struct"
    const columns_selection_and_mapping =
      Dict(
         :actor_id => "actor_id",
         :first_name => "first_name"
      )
    get_id_props() = return [:actor_id,:first_name]


    # A dictionnary of mapping between fields symbols and overriding types
    #   Left hanside is the field symbol ; right hand side is the type override
    const types_override = Dict()

    const track_changes = false
end

@testset "Test `util_get_ids_props_names(o::IEntity)` with a ORM with a function `get_id_props()``" begin
    myNewStruct = MyNewStruct(actor_id = 3,first_name="toto")
    PostgresORM.get_orm(myNewStruct)
    @test PostgresORM.Controller.util_get_ids_props_names(myNewStruct) == [:actor_id,:first_name]
end


# ####################################################### #
# TEST 2: The ORM doesn't have a function 'get_id_props()'
#            but has a id_property defined as a vector
# ####################################################### #
module MyNewStructORM
    data_type = Main.MyNewStruct
    Main.PostgresORM.get_orm(x::Main.MyNewStruct) = return(MyNewStructORM)
    get_table_name() = "public.my_new_struct"
    const columns_selection_and_mapping =
      Dict(
         :actor_id => "actor_id",
         :first_name => "first_name"
      )
    id_property = [:actor_id,:first_name]


    # A dictionnary of mapping between fields symbols and overriding types
    #   Left hanside is the field symbol ; right hand side is the type override
    const types_override = Dict()

    const track_changes = false
end

@testset "Test `util_get_ids_props_names(o::IEntity)` with a ORM without a function `get_id_props()``" begin
    myNewStruct = MyNewStruct(actor_id = 3,first_name="toto")
    PostgresORM.get_orm(myNewStruct)
    @test PostgresORM.Controller.util_get_ids_props_names(myNewStruct) == [:actor_id,:first_name]
end



# ####################################################### #
# TEST 3: The ORM doesn't have a function 'get_id_props()'
#            but has a id_property defined as a scalar
# ####################################################### #
module MyNewStructORM
    data_type = Main.MyNewStruct
    Main.PostgresORM.get_orm(x::Main.MyNewStruct) = return(MyNewStructORM)
    get_table_name() = "public.my_new_struct"
    const columns_selection_and_mapping =
      Dict(
         :actor_id => "actor_id",
         :first_name => "first_name"
      )
    id_property = :actor_id


    # A dictionnary of mapping between fields symbols and overriding types
    #   Left hanside is the field symbol ; right hand side is the type override
    const types_override = Dict()

    const track_changes = false
end

@testset "Test `util_get_ids_props_names(o::IEntity)` with a ORM without a function `get_id_props()``" begin
    myNewStruct = MyNewStruct(actor_id = 3,first_name="toto")
    orm_module = PostgresORM.get_orm(myNewStruct)
    @test PostgresORM.Controller.util_get_ids_props_names(myNewStruct) == [:actor_id]
end
