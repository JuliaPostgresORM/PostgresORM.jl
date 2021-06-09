include("runtests-prerequisite-Pagila.jl")

using PostgresORM.Tool

out_dir = (@__DIR__) * "/out"
dbconn = Main.Pagila.PagilaUtil.openDBConn()
result = Tool.generate_julia_structs_from_database(dbconn, out_dir)

Tool.remove_id_from_name("actor_id")
Tool.remove_id_from_name("id_actor")

dbanalysis = PostgresORM.SchemaInfo.analyse_db_schema(dbconn)
dbanalysis

tabledef = dbanalysis["public"]["rental"]
tabledef[:pk]

object_model = Tool.generate_object_model(dbconn)

object_model[:fields] |>
n -> filter(x -> x[:struct][:name] == "Film",n) |>
n -> filter(x -> x[:name] == "rating",n)


object_model
object_model[:fields] |>
  n -> filter(x -> (x[:struct][:name] == "FilmCategory"),n) |>
  n -> filter(x -> x[:is_manytoone],n) |>
  n -> filter(x -> x[:field_type] == "Public.Film",n) |>
  length



Tool.generate_orms_from_object_model(object_model, out_dir)
println(object_model[:structs][9][:orm_content])

Tool.generate_structs_from_object_model(object_model, out_dir)
println(object_model[:structs][9][:struct_content])

Tool.generate_julia_code(dbconn, out_dir)

referencing_cols = []
for v in (class_model |> values |> collect |>
                vect -> map(x -> x[:referencing_cols],vect))
  push!(referencing_cols,v...)
end



Main.Pagila.PagilaUtil.closeDBConn(dbconn)

using StringCases
StringCases.snakecase("mpaa_rating")
