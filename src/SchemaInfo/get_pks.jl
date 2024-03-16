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
