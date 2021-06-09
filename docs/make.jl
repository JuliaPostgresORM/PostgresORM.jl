using Documenter, PostgresORM

makedocs(sitename="PostgresORM documentation",
        modules  = [PostgresORM],
                pages=[
                       "Home" => "index.md"
                      ])
deploydocs(;repo="github.com/JuliaPostgresORM/PostgresORM.jl",)
