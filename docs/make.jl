import Pkg;
#Pkg.add("Documenter")
using Documenter, PostgresORM

makedocs(
        sitename = "PostgresORM documentation",
        modules = [PostgresORM],
        pages = ["Index" => "index.md",
                 "Getting started" => "getting-started.md",
                 "Modules" => [
                        "modules/PostgresORM.md",
                        # "modules/PostgresORM.Controller.md"
                        ]
                 ],
)
deploydocs(; repo = "github.com/JuliaPostgresORM/PostgresORM.jl.git",
             devbranch = "main")
