function SchemaInfo.get_table_comment(
    table::String, schema::String, dbconn::LibPQ.Connection
)::Union{Missing,String}

    querystr = "
    SELECT
    pg_catalog.obj_description(pg_class.oid, 'pg_class') AS table_comment
    FROM
    pg_catalog.pg_class
    INNER JOIN
    pg_catalog.pg_namespace ON pg_namespace.oid = pg_class.relnamespace
    WHERE
    pg_class.relname = \$2
    AND pg_namespace.nspname = \$1
    "

    queryres = execute_plain_query(querystr, [schema,table], dbconn)

    return queryres.table_comment[1]

end
