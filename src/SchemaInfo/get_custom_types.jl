function SchemaInfo.get_custom_types(dbconn::LibPQ.Connection)


    #  schema |    name    | internal_name | size |  elements  | description
    # --------+------------+---------------+------+------------+-------------
    #  public | value_type | value_type    | 4    | ordinal   +|
    #         |            |               |      | continuous+|
    #         |            |               |      | category  +|
    #         |            |               |      | bool      +|
    #         |            |               |      | text       |

    query_string = "SELECT n.nspname AS schema,
          pg_catalog.format_type ( t.oid, NULL ) AS name,
          t.typname AS internal_name,
          CASE
              WHEN t.typrelid != 0
              THEN CAST ( 'tuple' AS pg_catalog.text )
              WHEN t.typlen < 0
              THEN CAST ( 'var' AS pg_catalog.text )
              ELSE CAST ( t.typlen AS pg_catalog.text )
          END AS size,
          pg_catalog.array_to_string (
              ARRAY( SELECT e.enumlabel
                      FROM pg_catalog.pg_enum e
                      WHERE e.enumtypid = t.oid
                      ORDER BY e.oid ), E'\n'
              ) AS elements,
          pg_catalog.obj_description ( t.oid, 'pg_type' ) AS description
      FROM pg_catalog.pg_type t
      LEFT JOIN pg_catalog.pg_namespace n
          ON n.oid = t.typnamespace
      WHERE ( t.typrelid = 0
              OR ( SELECT c.relkind = 'c'
                      FROM pg_catalog.pg_class c
                      WHERE c.oid = t.typrelid
                  )
          )
          AND NOT EXISTS
              ( SELECT 1
                  FROM pg_catalog.pg_type el
                  WHERE el.oid = t.typelem
                      AND el.typarray = t.oid
              )
          AND n.nspname <> 'pg_catalog'
          AND n.nspname <> 'information_schema'
          AND pg_catalog.pg_type_is_visible ( t.oid )
      ORDER BY 1, 2;"

    cols = execute_plain_query(query_string,
                                [],
                                dbconn)

    result = Dict()

    for c in eachrow(cols)
        name_ = c.internal_name
        possible_values = string.(split(c.elements, "\n"))
        # Cleaning
        filter!(x-> length(x) > 0,possible_values)
        result[name_] = Dict(
           :name => name_,
           :possible_values => possible_values
        )
    end

    return result

end
