# module CacheModule

using .Cache
using .PostgresORM: FKInfo

"""
    add_to_cache(key, value)

Add a key-value pair to the cache.
"""
function Cache.add_to_cache(key, value)
    cache = Cache._ensure_cache_initialized()
    cache[key] = value
end

"""
    get_from_cache(key, default=missing)

Retrieve a value from the cache by its key.
Return `default` if the key is not found.
"""
function Cache.get_from_cache(key, default=missing)
    cache = Cache._ensure_cache_initialized()
    return get(cache, key, default)
end

"""
    remove_from_cache(key)

Remove a key-value pair from the cache by its key.
"""
function Cache.remove_from_cache(key)
    cache = Cache._ensure_cache_initialized()
    delete!(cache, key)
end

"""
    clear_cache()

Clear all items from the cache.
"""
function Cache.clear_cache()
    cache = Cache._ensure_cache_initialized()
    empty!(cache)
end

"""
    cache_keys()

Return a list of all keys in the cache.
"""
function Cache.cache_keys()
    cache = Cache._ensure_cache_initialized()
    return keys(cache)
end

"""
    cache_values()

Return a list of all values in the cache.
"""
function Cache.cache_values()
    cache = Cache._ensure_cache_initialized()
    return values(cache)
end

# function Cache.to ensure cache is initialized
function Cache._ensure_cache_initialized()
    if isnothing(Cache._cache_ref[])
        Cache._cache_ref[] = Dict{Any, Any}()
    end
    return Cache._cache_ref[]
end

function Cache.get_db_entry_key_for_cache(dbconn::LibPQ.Connection)

    if !isopen(dbconn)
        error("PostgreSQL connection (closed)")
    end

    keywords_of_interest = [
        "host", "port", "dbname"
    ]

    conninfo = LibPQ.conninfo(dbconn)

    result_elts = String[]
    for keyword in keywords_of_interest
        for ci_opt in conninfo
            if ci_opt.keyword == keyword
                push!(result_elts, string(ci_opt.val))
            end
        end
    end

    return join(result_elts, "/")

end

function Cache.generate_fk2pk_mapping_cache(dbconn::LibPQ.Connection)

    fkinfos = FKInfo[]

    for referencing_schema in SchemaInfo.get_schemas(dbconn)
        for referencing_table in SchemaInfo.get_tables(referencing_schema, dbconn)
            for (constraint_name,v) in SchemaInfo.get_fks(referencing_table, referencing_schema, dbconn)

                referenced_table = v[:referenced_table][:table]
                referenced_schema = v[:referenced_table][:schema]
                for (referencing_col,referenced_col) in zip(v[:referencing_cols],v[:referenced_cols])
                    push!(
                        fkinfos,
                        FKInfo(
                            constraint_name = constraint_name,
                            referencing_table = referencing_table,
                            referencing_schema = referencing_schema,
                            referencing_col = referencing_col,
                            referenced_table = referenced_table,
                            referenced_schema = referenced_schema,
                            referenced_col = referenced_col
                        )
                    )
                end

            end
        end
    end

    #
    cache = Cache._ensure_cache_initialized()

    db_key = Cache.get_db_entry_key_for_cache(dbconn::LibPQ.Connection)
    if ismissing(Cache.get_from_cache(db_key, missing))
        Cache.add_to_cache(db_key, Dict{Symbol, Any}())
    end

    if !haskey(cache[db_key], :fkcol2pkcol)
        cache[db_key][:fkcol2pkcol] = Dict{
            String, # schema
            Dict{
                String, # table
                Dict{
                    String, # fk col in referencing table
                    Dict{
                        String, # referenced table (a fk col can be involved in several FKs)
                        NamedTuple
                    }
                }
            }
        }()
    end

    for fkinfo in fkinfos

        # Check that entry for referencing shema exists
        if !haskey(cache[db_key][:fkcol2pkcol], fkinfo.referencing_schema)
            cache[db_key][:fkcol2pkcol][fkinfo.referencing_schema] = Dict{
                String, # table
                Dict{
                    String, # fk col in referencing table
                    Dict{
                        String, # referenced table (a fk col can be involved in several FKs)
                        NamedTuple
                    }
                }
            }()
        end

        # Check that entry for referencing table exists
        if !haskey(cache[db_key][:fkcol2pkcol][fkinfo.referencing_schema], fkinfo.referencing_table)
            cache[db_key][:fkcol2pkcol][fkinfo.referencing_schema][fkinfo.referencing_table] = Dict{
                String, # fk col in referencing table
                Dict{
                    String, # referenced table (a fk col can be involved in several FKs)
                    NamedTuple
                }
            }()
        end

        # Check that entry for referencing column exists
        if !haskey(cache[db_key][:fkcol2pkcol][fkinfo.referencing_schema], fkinfo.referencing_table)
            cache[db_key][:fkcol2pkcol][fkinfo.referencing_schema][fkinfo.referencing_table][fkinfo.referencing_col] = Dict{
                String, # fk col in referencing table
                Dict{
                    String, # referenced table (a fk col can be involved in several FKs)
                    NamedTuple
                }
            }()
        end

        cache[db_key][:fkcol2pkcol][fkinfo.referencing_schema][fkinfo.referencing_table][fkinfo.referencing_col] =
            (schema=fkinfo.referenced_schema, table=fkinfo.referenced_table, col=fkinfo.referenced_col)
    end

end

function Cache.__init__()
    @info("Init PostgresORM.Cache module")
    # Initialize the cache when the module is loaded
    Cache._cache_ref[] = Dict{Any, Any}()
end

export add_to_cache, get_from_cache, remove_from_cache, clear_cache, cache_keys, cache_values

# end # module
