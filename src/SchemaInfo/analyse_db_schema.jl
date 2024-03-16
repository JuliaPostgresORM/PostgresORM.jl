function SchemaInfo.analyse_db_schema(dbconn::LibPQ.Connection)

    result = Dict()

    for schema in SchemaInfo.get_schemas(dbconn)
        result[schema] = Dict()
        for tbl in SchemaInfo.get_tables(schema, dbconn)
            result[schema][tbl] = Dict(
                :comment => SchemaInfo.get_table_comment(tbl, schema, dbconn),
                :pk => SchemaInfo.get_pks(tbl, schema, dbconn),
                :fks => SchemaInfo.get_fks(tbl, schema, dbconn),
                :cols => SchemaInfo.get_columns_types(tbl,schema, dbconn),
                :is_partition => SchemaInfo.check_if_table_is_partition_of_another_table(tbl, schema, dbconn)
            )
        end # ENDOF for SchemaInfo.get_tables
    end # ENDOF for schema

    return result

 end
