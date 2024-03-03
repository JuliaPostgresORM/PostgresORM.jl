function SchemaInfo.check_if_table_is_partition_of_another_table(
    table::String,
    schema::String,
    dbconn::LibPQ.Connection
)

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
