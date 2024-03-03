
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
