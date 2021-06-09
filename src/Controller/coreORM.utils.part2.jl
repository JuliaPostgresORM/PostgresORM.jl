#                    host        dbname      table       col    type
columns_types = Dict{String, # host
                     Dict{String, # dbname
                          Dict{String, # schema
                               Dict{String, # table
                                    Dict{String,String} # column, type
                                    }
                               }
                          }
                     }()
function util_get_column_type(dbconn::LibPQ.Connection,
                              tablename::String,
                              schema::String,
                              colname::String,
                              refresh = false)

     dbname = util_getdbname(dbconn)
     host = util_getdbhost(dbconn)

     if !haskey(columns_types, host)
         columns_types[host] = Dict{String, # dbname
                                    Dict{String, # schema
                                         Dict{String, # table
                                              Dict{String,String} # column, type
                                              }
                                         }
                                    }()
     end
     if !haskey(columns_types[host], dbname)
         columns_types[host][dbname] = Dict{String, # schema
                                            Dict{String, # table
                                                 Dict{String,String} # column, type
                                                 }
                                            }()
     end
     if !haskey(columns_types[host][dbname], schema)
         columns_types[host][dbname][schema] = Dict{String, # table
                                                        Dict{String,String} # column, type
                                                        }()
     end
     if !haskey(columns_types[host][dbname][schema], tablename)
         columns_types[host][dbname][schema][tablename] = Dict{String,String}()
     end
     if (!haskey(columns_types[host][dbname][schema][tablename], colname)
          || refresh == true)
         # Get the type from database
         query_string = "SELECT data_type from information_schema.columns
                            WHERE table_schema = \$1
                              AND table_name = \$2
                              AND column_name = \$3"

         query_result = execute_plain_query(query_string,
                              [schema, tablename,colname],
                              dbconn)
         if nrow(query_result) == 0
             error("Unable to retrieve the type of column[$colname] "
             * "in table[$tablename] of schema[$schema]")
         end

         coltype::String = query_result[1,1]
         columns_types[host][dbname][schema][tablename][colname] = coltype
     else
         coltype = columns_types[host][dbname][schema][tablename][colname]
     end

     return coltype

end


function util_is_column_numeric(dbconn::LibPQ.Connection,
                                tablename::String,
                                schema::String,
                                colname::String)

    coltype = util_get_column_type(dbconn,
                                   tablename,
                                   schema,
                                   colname)

    if coltype in (["smallint","integer","bigint","decimal","numeric","real",
                    "double precision","smallserial","serial","bigserial"])
       return true
    end

   return false

end
