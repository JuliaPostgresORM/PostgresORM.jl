function SchemaInfo.get_schemas(dbconn::LibPQ.Connection)

    querystr = "SELECT n.nspname AS \"Name\",
                pg_catalog.pg_get_userbyid(n.nspowner) AS \"Owner\"
                FROM pg_catalog.pg_namespace n
                WHERE n.nspname !~ '^pg_' AND n.nspname <> 'information_schema'
                ORDER BY 1;"

    queryres = execute_plain_query(querystr, [], dbconn)
    return convert(Vector{String}, queryres.Name)
 end
