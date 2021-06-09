using LibPQ
using ..PostgresORMUtil, ..Controller

function SchemaInfo.analyse_db_schema(dbconn::LibPQ.Connection)

   result = Dict()

   for schema in SchemaInfo.get_schemas(dbconn)
      result[schema] = Dict()
      for tbl in SchemaInfo.get_tables(schema, dbconn)
         result[schema][tbl] = Dict(
            :pk => SchemaInfo.get_pks(tbl, schema, dbconn),
            :fks => SchemaInfo.get_fks(tbl, schema, dbconn),
            :cols => SchemaInfo.get_columns_types(tbl,schema, dbconn),
            :is_partition => SchemaInfo.check_if_table_is_partition_of_another_table(tbl, schema, dbconn)
         )
      end # ENDOF for SchemaInfo.get_tables
   end # ENDOF for schema

   return result

end

function SchemaInfo.get_schemas(dbconn::LibPQ.Connection)

   querystr = "SELECT n.nspname AS \"Name\",
               pg_catalog.pg_get_userbyid(n.nspowner) AS \"Owner\"
               FROM pg_catalog.pg_namespace n
               WHERE n.nspname !~ '^pg_' AND n.nspname <> 'information_schema'
               ORDER BY 1;"

   queryres = execute_plain_query(querystr, [], dbconn)
   return convert(Vector{String}, queryres.Name)
end

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
   println(querystr)
   schema_pattern = "^($schema)\$"
   queryres = execute_plain_query(querystr, [schema_pattern], dbconn)
   return convert(Vector{String}, queryres.Name)

end

function SchemaInfo.check_if_table_is_partition_of_another_table(
            table::String,
            schema::String,
            dbconn::LibPQ.Connection)

    #   SELECT c.relchecks, c.relkind, c.relhasindex, c.relhasrules, c.relhastriggers, c.relrowsecurity, c.relforcerowsecurity, false AS relhasoids, c.relispartition, '', c.reltablespace, CASE WHEN c.reloftype = 0 THEN '' ELSE c.reloftype::pg_catalog.regtype::pg_catalog.text END, c.relpersistence, c.relreplident, am.amname
    # FROM pg_catalog.pg_class c
    #  LEFT JOIN pg_catalog.pg_class tc ON (c.reltoastrelid = tc.oid)
    # LEFT JOIN pg_catalog.pg_am am ON (c.relam = am.oid)
    # WHERE c.oid = '116102';

   oid = SchemaInfo.get_table_oid(table, schema, dbconn)
   querystr = "SELECT c.relispartition
       FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_class tc ON (c.reltoastrelid = tc.oid)
       LEFT JOIN pg_catalog.pg_am am ON (c.relam = am.oid)
       WHERE c.oid = \$1;"

    queryres = execute_plain_query(querystr, [oid], dbconn)
    return queryres.relispartition[1]

end

function SchemaInfo.check_if_table_or_partition_exists(table::String,
                                                       schema::String,
                                                       dbconn::LibPQ.Connection)
    querystr = "SELECT EXISTS (
                   SELECT FROM information_schema.tables
                   WHERE  table_name  = \$1
                   AND    table_schema = \$2
                   );"
    queryres = execute_plain_query(querystr, [table, schema], dbconn)
    return queryres[1,1]
end

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

function SchemaInfo.get_pks(table::String, schema::String, dbconn::LibPQ.Connection)

   # pagila=# SELECT c2.relname, i.indisprimary, i.indisunique, i.indisclustered, i.indisvalid, pg_catalog.pg_get_indexdef(i.indexrelid, 0, true),
   # pagila-#   pg_catalog.pg_get_constraintdef(con.oid, true), contype, condeferrable, condeferred, i.indisreplident, c2.reltablespace
   # pagila-# FROM pg_catalog.pg_class c, pg_catalog.pg_class c2, pg_catalog.pg_index i
   # pagila-#   LEFT JOIN pg_catalog.pg_constraint con ON (conrelid = i.indrelid AND conindid = i.indexrelid AND contype IN ('p','u','x'))
   # pagila-# WHERE c.oid = '106295' AND c.oid = i.indrelid AND i.indexrelid = c2.oid
   # pagila-# ORDER BY i.indisprimary DESC, i.indisunique DESC, c2.relname;
   #      relname     | indisprimary | indisunique | indisclustered | indisvalid |                                  pg_get_indexdef                                  |      pg_get_constraintdef       | contype | condeferrable | condeferred | i
   # ndisreplident | reltablespace
   # -----------------+--------------+-------------+----------------+------------+-----------------------------------------------------------------------------------+---------------------------------+---------+---------------+-------------+--
   # --------------+---------------
   #  film_actor_pkey | t            | t           | f              | t          | CREATE UNIQUE INDEX film_actor_pkey ON film_actor USING btree (actor_id, film_id) | PRIMARY KEY (actor_id, film_id) | p       | f             | f           | f
   #               |             0
   #  idx_fk_film_id  | f            | f           | f              | t          | CREATE INDEX idx_fk_film_id ON film_actor USING btree (film_id)                   |                                 |         |               |             | f
   #               |             0
   # (2 rows)


   querystr = "SELECT c2.relname, i.indisprimary, i.indisunique, i.indisclustered, i.indisvalid, pg_catalog.pg_get_indexdef(i.indexrelid, 0, true),
               pg_catalog.pg_get_constraintdef(con.oid, true), contype, condeferrable, condeferred, i.indisreplident, c2.reltablespace
                FROM pg_catalog.pg_class c, pg_catalog.pg_class c2, pg_catalog.pg_index i
                  LEFT JOIN pg_catalog.pg_constraint con ON (conrelid = i.indrelid AND conindid = i.indexrelid AND contype IN ('p','u','x'))
                WHERE c.oid = \$1 AND c.oid = i.indrelid AND i.indexrelid = c2.oid
                ORDER BY i.indisprimary DESC, i.indisunique DESC, c2.relname;"

   table_oid = SchemaInfo.get_table_oid(table, schema, dbconn)

   queryres = execute_plain_query(querystr, [table_oid], dbconn)
   pg_get_constraintdef = filter(x -> begin
                                          !ismissing(x) && startswith(x,"PRIMARY KEY")
                                      end,
                                 queryres.pg_get_constraintdef)

   pg_get_constraintdef =  convert(Vector{String}, pg_get_constraintdef)
   # pg_get_constraintdef = map(x -> replace(x, " " => ""), pg_get_constraintdef)
   # return pg_get_constraintdef

   result = Vector{String}()
   for str in pg_get_constraintdef
      pks = match(r"^PRIMARY KEY \((.*)\)$",str)
      pks =  convert(Vector{String}, pks.captures)
      tmp_res = String[]
      for pk in pks
         push!(tmp_res,
               remove_spaces_and_split(pk)...)
      end
      sort!(tmp_res) # IMPORTANT! Sort the PK columns, we'll do the same with
                     #            the FK columns
      push!(result, tmp_res...)
   end

   return result


end


function SchemaInfo.get_fks(table::String, schema::String, dbconn::LibPQ.Connection)

   # pagila=# SELECT true as sametable, conname,
   # pagila-#   pg_catalog.pg_get_constraintdef(r.oid, true) as condef,
   # pagila-#   conrelid::pg_catalog.regclass AS ontable
   # pagila-# FROM pg_catalog.pg_constraint r
   # pagila-# WHERE r.conrelid = '106295' AND r.contype = 'f'
   # pagila-#      AND conparentid = 0
   # pagila-# ORDER BY conname
   # pagila-#
   # pagila-# ;
   #  sametable |         conname          |                                         condef                                         |  ontable
   # -----------+--------------------------+----------------------------------------------------------------------------------------+------------
   #  t         | film_actor_actor_id_fkey | FOREIGN KEY (actor_id) REFERENCES actor(actor_id) ON UPDATE CASCADE ON DELETE RESTRICT | film_actor
   #  t         | film_actor_film_release_year_fkey  | FOREIGN KEY (film_id, film_release_year) REFERENCES film(film_id, release_year)    | film_actor
   # (2 rows)

   querystr = "SELECT true as sametable, conname,
               pg_catalog.pg_get_constraintdef(r.oid, true) as condef,
                  conrelid::pg_catalog.regclass AS ontable
                FROM pg_catalog.pg_constraint r
                WHERE r.conrelid = \$1 AND r.contype = 'f'
                     AND conparentid = 0
                ORDER BY conname"

   table_oid = SchemaInfo.get_table_oid(table, schema, dbconn)

   queryres = execute_plain_query(querystr, [table_oid], dbconn)
   queryres = filter(x -> begin
                           !ismissing(x.condef) && startswith(x.condef,"FOREIGN KEY")
                       end,
                    queryres)

   result = Dict()
   for r in eachrow(queryres)
      fks = match(r"^FOREIGN KEY \((.*)\) REFERENCES (.*)\((.*)\)",r.condef)
      # @info fks.captures

      # Referencing columns
      referencing_cols = remove_spaces_and_split(string(fks.captures[1]))
      referencing_cols = string.(referencing_cols)

      # Referenced table
      referenced_table = remove_spaces_and_split(string(fks.captures[2]))[1]
      referenced_schema = "public"
      if occursin(".",referenced_table)
         referenced_table_arr = split(referenced_table,'.')
         referenced_table = referenced_table_arr[2]
         referenced_schema = referenced_table_arr[1]
      end

      # Referenced columns
      referenced_cols = remove_spaces_and_split(string(fks.captures[3]))
      referenced_cols = string.(referenced_cols)

      # Reorder the pairs (PK column, FK column) according to the PK columns
      ordered_cols_along_pk_cols =
         collect(zip(referenced_cols, referencing_cols)) |>
         n -> sort(n, by = x -> x[1])
      referenced_cols = map(x -> x[1],ordered_cols_along_pk_cols)
      referencing_cols = map(x -> x[2],ordered_cols_along_pk_cols)

      result[r.conname] = Dict(
         :referencing_cols => referencing_cols,
         :referenced_table => Dict(:table => string(referenced_table),
                                   :schema => string(referenced_schema)),
         :referenced_cols => referenced_cols
      )

   end



   return result


end

function SchemaInfo.get_columns_types(table::String,schema::String, dbconn::LibPQ.Connection)
   query_string = "SELECT column_name,
                          data_type AS column_type,
                          udt_name AS element_type
                   from information_schema.columns
                   WHERE table_schema = \$1 AND table_name = \$2"

   cols = execute_plain_query(query_string,
                              [schema,table],
                              dbconn)

    result = Dict()

   for c in eachrow(cols)
      colname = c.column_name
      coltype = c.column_type
      elttype = c.element_type
      result[colname] = Dict(
         :type => coltype,
         :elttype_if_array => elttype
      )
   end

   return result

end


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
