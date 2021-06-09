mutable struct Modification <: IModification

    id::Union{Missing,String}
    entity_type::Union{Missing,String}
    entity_id::Union{Missing,String}
    attrname::Union{Missing,String}
    oldvalue::Union{Missing,String}
    newvalue::Union{Missing,String}
    appuser_id::Union{Missing,String}
    action_id::Union{Missing,UUID}
    action_type::Union{Missing,CRUDType.CRUD}
    creation_time::Union{DateTime,Missing}

    # Do not use the following contructor because it gets into conflict with
    #   the one with optional arguments :
    # AppUser() = new(missing,missing,missing,missing,missing,missing,missing)

    # Convenience constructor that allows us to create a vector of instances
    #   from a JuliaDB.table using the dot syntax: `Myclass.(a_JuliaDB_table)`
    Modification(args::NamedTuple) = Modification(;args...)
    Modification(;id = missing,
             entity_type = missing,
             entity_id = missing,
             attrname = missing,
             oldvalue = missing,
             newvalue = missing,
             appuser_id = missing,
             action_id = missing,
             action_type = missing,
             creation_time = missing) = (
                  # First call the default constructor with missing values only so that
                  #   there is no risk that we don't assign an argument to the wrong attribute
                  x = new(missing, missing, missing, missing, missing,
                          missing, missing, missing, missing, missing);
                  x.id = id;
                  x.entity_type = entity_type;
                  x.entity_id = entity_id;
                  x.attrname = attrname;
                  x.oldvalue = oldvalue;
                  x.newvalue = newvalue;
                  x.appuser_id = appuser_id;
                  x.action_id = action_id;
                  x.action_type = action_type;
                  x.creation_time = creation_time;

                  return x )

end
