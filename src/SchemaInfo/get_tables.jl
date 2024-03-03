function SchemaInfo.get_tables(schema::String, dbconn::LibPQ.Connection)

    querystr = "SELECT n.nspname as \"Schema\",
                  c.relname as \"Name\",
                  CASE c.relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'm' THEN 'materialized view' WHEN 'i' THEN 'index' WHEN 'S' THEN 'sequence' WHEN 's' THEN 'special' WHEN 'f' THEN 'foreign table' WHEN 'p' THEN 'partitioned table' WHEN 'I' THEN 'partitioned index' END as \"Type\",
                  pg_catalog.pg_get_userbyid(c.relowner) as \"Owner\"
                FROM pg_catalog.pg_class c
                     LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relkind IN ('r','p','s','')
                      AND n.nspname !~ '^pg_toast'
                  AND n.nspname OPERATOR(pg_catalog.~) \$1 COLLATE pg_catalog.default
                ORDER BY 1,2;"
    schema_pattern = "^($schema)\$"
    queryres = execute_plain_query(querystr, [schema_pattern], dbconn)
    return convert(Vector{String}, queryres.Name)

 end
