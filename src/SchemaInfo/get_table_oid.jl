function SchemaInfo.get_table_oid(table::String, schema::String, dbconn::LibPQ.Connection)

    # pagila=# SELECT c.oid,
    # pagila-#   n.nspname,
    # pagila-#   c.relname
    # pagila-# FROM pg_catalog.pg_class c
    # pagila-#      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    # pagila-# WHERE c.relname OPERATOR(pg_catalog.~) '^(film_actor)$' COLLATE pg_catalog.default
    # pagila-#   AND pg_catalog.pg_table_is_visible(c.oid)
    # pagila-# ORDER BY 2, 3;
    #   oid   | nspname |  relname
    # --------+---------+------------
    #  106295 | public  | film_actor
    # (1 row)

    querystr = "SELECT c.oid,
                n.nspname,
                c.relname
                FROM pg_catalog.pg_class c
                      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                 WHERE c.relname OPERATOR(pg_catalog.~) \$1 COLLATE pg_catalog.default
                   AND n.nspname OPERATOR(pg_catalog.~) \$2 COLLATE pg_catalog.default
                   ORDER BY 2, 3;"

    table_pattern  = "^($table)\$"
    schema_pattern = "^($schema)\$"

    queryres = execute_plain_query(querystr, [table_pattern,schema_pattern], dbconn)
    return signed(queryres.oid[1])

 end
