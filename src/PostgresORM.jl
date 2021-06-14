module PostgresORM

  export greet, get_orm, create_entity!, create_in_bulk_using_copy,
         delete_entity, delete_entity_alike,
         retrieve_entity,
         update_entity!, update_vector_property!

  export IEntity, IAppUser, Modification

  using Dates, UUIDs

  function get_orm end

  include("./enums/CRUDType.jl")

  # Add the types used by the package
  # NOTE: We make it available at the root of the module because they are used
  #         by the calling libraries
  include("./model/abstract_types.jl")
  include("./model/Modification.jl")

  # This is a failed attempt to put the API in the module.
  # It works, but despite Revise, the web server does not take into account the
  #   changes. Therefore we prefer to have it put in the main module so that we
  #   can easily reload it.
  # module WebApi
  #   using ..PostgresORM
  #   export web_api
  #   include("./web-api-definition.jl")
  # end

  greet() = return ("Hello World!")

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



  module Controller

    using ..CRUDType, ..PostgresORM
    using ..PostgresORMUtil
    # using .ModificationORM # no need (because ModificationORM is a children module ?)
    using Tables, DataFrames, Query, LibPQ, Dates, UUIDs, TickTock, TimeZones,
          JSON
    using IterTools:imap

    include("./Controller/coreORM.utils.part1.jl")
    include("./Controller/coreORM.create.jl")
    include("./Controller/coreORM.retrieve.jl")
    include("./Controller/coreORM.update.jl")
    include("./Controller/coreORM.delete.jl")
    include("./Controller/coreORM.utils.part2.jl")

    module ModificationORM
      using ..PostgresORM
      using ..PostgresORMUtil
      using ..Controller
      include("./Controller/ModificationORM.jl")
    end

  end # module Controller

  module Tool
    using LibPQ, StringCases
    using ..PostgresORM
    using ..Controller
    using ..CRUDType
    using ..PostgresORMUtil, ..SchemaInfo
    # using .ModificationORM # no need (because ModificationORM is a children module ?)
    using Tables, DataFrames, Query, LibPQ, Dates, UUIDs, TickTock
    include("./tool/Tool.jl")

  end # module Tool

  # Implementation of the SchemaInfo module
  include("./schema-info/SchemaInfo-imp.jl")


  include("./exposed-functions-from-submodules.jl")

end # ENDIF module PostgresORM