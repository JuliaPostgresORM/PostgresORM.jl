function SchemaInfo.get_columns_types(table::String,schema::String, dbconn::LibPQ.Connection)

    query_string = "
    SELECT
        c.column_name,
        c.data_type AS column_type,
        c.udt_name AS element_type,
        d.description AS column_comment
    FROM
        information_schema.columns c
    LEFT JOIN
        pg_description d ON d.objoid = (
            SELECT oid
            FROM pg_class
            WHERE relname = \$2
            AND relnamespace = (
                SELECT oid
                FROM pg_namespace
                WHERE nspname = \$1)
            )
            AND d.objsubid = (
                SELECT attnum
                FROM pg_attribute
                WHERE attrelid = (
                    SELECT oid
                    FROM pg_class
                    WHERE relname = \$2
                    AND relnamespace = (
                        SELECT oid
                        FROM pg_namespace
                        WHERE nspname = \$1
                    )
                )
                AND attname = c.column_name
            )
    WHERE c.table_schema = \$1
      AND c.table_name = \$2"

    cols = execute_plain_query(query_string,
                               [schema,table],
                               dbconn)

    result = Dict()

    for c in eachrow(cols)
       colname = c.column_name
       coltype = c.column_type
       elttype = c.element_type
       comment = c.column_comment
       result[colname] = Dict(
          :type => coltype,
          :elttype_if_array => elttype,
          :comment => comment
       )
    end

    return result

end
