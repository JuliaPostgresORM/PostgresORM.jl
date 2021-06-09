module Pagila


  export greet

  # This is a failed attempt to put the API in the module.
  # It works, but despite Revise, the web server does not take into account the
  #   changes. Therefore we prefer to have it put in the main module so that we
  #   can easily reload it.
  # module WebApi
  #   using ..TestApp
  #   export web_api
  #   include("./web-api-definition.jl")
  # end

  greet() = return ("Hello World")

  module PagilaUtil

      using LibPQ, DataFrames, ConfParser

      include("./util/utils.jl")

  end # module TestAppUtil

  module Model

    using Dates, TimeZones, UUIDs, PostgresORM, PostgresORM.Model
    export Actor, Film, FilmActorAsso

    include("./model/abstract_types.jl")
    include("./model/Actor.jl")
    include("./model/Film.jl")
    include("./model/FilmActorAsso.jl")

  end # module Model

  module ORM
    using ..Model, PostgresORM
    module ActorORM
      using ..Model, PostgresORM
      include("./orm/ActorORM.jl")
    end
    module FilmORM
      using ..Model, PostgresORM
      include("./orm/FilmORM.jl")
    end
    module FilmActorAssoORM
      using ..Model, PostgresORM
      include("./orm/FilmActorAssoORM.jl")
    end
  end # modeule ORM

config = PagilaUtil.loadConf()

end  # Pagila
