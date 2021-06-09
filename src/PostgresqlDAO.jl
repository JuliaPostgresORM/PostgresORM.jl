module PostgresORM

  export greet, get_orm, create_entity!, create_in_bulk_using_copy,
         delete_entity, delete_entity_alike,
         retrieve_entity, retrieve_one_entity,
         update_entity!, update_vector_property!

  function get_orm end

  # This is a failed attempt to put the API in the module.
  # It works, but despite Revise, the web server does not take into account the
  #   changes. Therefore we prefer to have it put in the main module so that we
  #   can easily reload it.
  # module WebApi
  #   using ..PostgresORM
  #   export web_api
  #   include("./web-api-definition.jl")
  # end

  greet() = return ("Hello World")

  module PostgresORMUtil
      using ..PostgresORM
      using DataFrames, Dates, TimeZones

      export opendbconn, closedbconn, dict2namedtuple, namedtuple2dict, tovector,
            get_nonmissing_typeof_uniontype, dataframe2vector_of_namedtuples,
            dataframerow2namedtuple, getdictvalues, getpropertiesvalues,
            setpropertiesvalues!, remove_spaces_and_split, diff_dict, string2enum,
            int2enum, enum2int, dictstringkeys2symbol, dictnothingvalues2missing,
            getproperties_asdict, string2zoneddatetime
      include("./util/utils.jl")

  end # module PostgresORMUtil

  # Provides functions to get information about the database structures
  module SchemaInfo
      include("./schema-info/SchemaInfo-def.jl") # This is only the definition of the
                                                 #   module. See below for the actual
                                                 #   implementation.
  end #module SchemaInfo

  module Model

      using Dates, UUIDs
      using ..PostgresORM

      module Enums
        include("./model/Enums.jl")
      end

      export IEntity, IAppUser, Modification
      include("./model/abstract_types.jl")
      include("./model/Modification.jl")

  end # module Model

  module Controller
    using ..PostgresORM
    using ..Model
    using ..Model.Enums
    using ..Model.Enums.CRUDType
    using ..PostgresORMUtil
    # using .ModificationORM # no need (because ModificationORM is a children module ?)
    using Tables, DataFrames, Query, LibPQ, Dates, UUIDs, TickTock, TimeZones,
          JSON
    using IterTools:imap

    export create_entity!, retrieve_entity, retrieve_one_entity, update_entity!,
           delete_entity, delete_entity_alike, create_in_bulk_using_copy,
           util_diff_entities, util_remove_trackchanges_properties_from_dict,
           util_get_entity_props_for_comparison, util_compare_and_sync_entities,
           update_vector_property!, createsomething,
           execute_query_and_handle_result, execute_plain_query,
           util_dict2entity, util_replace_complex_types_by_id,
           util_replace_dict_types, util_replace_enums_by_id,
           util_overwrite_props!, util_get_column_type, util_getdbname,
           util_getdbhost, util_is_column_numeric

    include("./controller/CoreORM.utils.part1.jl")
    include("./controller/CoreORM.create.jl")
    include("./controller/CoreORM.retrieve.jl")
    include("./controller/CoreORM.update.jl")
    include("./controller/CoreORM.delete.jl")
    include("./controller/CoreORM.utils.part2.jl")

    module ModificationORM
      using ..PostgresORM
      using ..PostgresORMUtil
      using ..Model
      using ..Controller
      export create_modification, retrieve_modification, update_modification
      include("./controller/ModificationORM.jl")
    end

  end # module Controller

  module Tool
    using LibPQ, StringCases
    using ..PostgresORM
    using ..Controller
    using ..Model
    using ..Model.Enums
    using ..Model.Enums.CRUDType
    using ..PostgresORMUtil, ..SchemaInfo
    # using .ModificationORM # no need (because ModificationORM is a children module ?)
    using Tables, DataFrames, Query, LibPQ, Dates, UUIDs, TickTock
    include("./tool/Tool.jl")

  end # module Tool

  # Implementation of the SchemaInfo module
  include("./schema-info/SchemaInfo-imp.jl")

  #
  # include("./exposed-functions-from-submodules.jl")

end # module PostgresORM
