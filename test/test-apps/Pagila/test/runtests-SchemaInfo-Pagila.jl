include("runtests-prerequisite-Pagila.jl")

using PostgresORM.SchemaInfo

dbconn = Main.Pagila.PagilaUtil.openDBConn()

result = SchemaInfo.get_schemas(dbconn)
result = SchemaInfo.get_tables("public",dbconn)
result = SchemaInfo.get_table_oid("film_actor", "public", dbconn)
result = SchemaInfo.get_pks("film", "public", dbconn)
result = SchemaInfo.get_pks("film_actor", "public", dbconn)
result = SchemaInfo.get_fks("film_actor", "public", dbconn)
result = SchemaInfo.get_columns_types("film_actor", "public", dbconn)
result = SchemaInfo.check_if_table_is_partition_of_another_table("film_actor", "public", dbconn)
result = SchemaInfo.check_if_table_or_partition_exists("film_actor", "public",
                                                        dbconn)
result = SchemaInfo.get_custom_types(dbconn)

SchemaInfo.analyse_db_schema(dbconn)
