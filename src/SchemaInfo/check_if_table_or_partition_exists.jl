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
