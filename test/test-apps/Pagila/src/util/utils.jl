# see ~/.julia/config/startup.jl for setting the environment variable
function loadConf()::ConfParse
    conf_file = conf_file = joinpath(@__DIR__,"../../conf/pagila.conf")
    conf = ConfParse(conf_file)
    parse_conf!(conf)
    return(conf)
end

function getConf(category_name::String,property_name::String)
    ConfParser.retrieve(Main.Pagila.config,
                        category_name,
                        property_name)
end

function openDBConn()
    database = getConf("database","database")
    user = getConf("database","user")
    host = getConf("database","host")
    port = getConf("database","port")
    password = getConf("database","password")

    conn = LibPQ.Connection("host=$(host)
                             port=$(port)
                             dbname=$(database)
                             user=$(user)
                             password=$(password)
                             "; throw_error=true)
    # We want Postgresql planner to optimize the query over the partitions
    # https://www.postgresql.org/docs/12/ddl-partitioning.html#DDL-PARTITION-PRUNING
    # The property is set for the SESSION
    execute(conn, "SET enable_partition_pruning = on;")

    return conn
end

function openDBConnAndBeginTransaction()
    conn = openDBConn()
    beginDBTransaction(conn)
    return conn
end

function beginDBTransaction(conn)
    execute(conn, "BEGIN;")
end

function commitDBTransaction(conn)
    execute(conn, "COMMIT;")
end

function rollbackDBTransaction(conn)
    execute(conn, "ROLLBACK;")
end

function closeDBConn(conn)
    close(conn)
end
