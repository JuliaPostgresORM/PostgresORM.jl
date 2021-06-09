mutable struct Actor <: IActor

  actor_id::Union{Missing,Int32}
  first_name::Union{Missing,String}
  last_name::Union{Missing,String}
  last_update::Union{Missing,DateTime}

  Actor(args::NamedTuple) = Actor(;args...)
  Actor(;
        actor_id = missing,
        first_name = missing,
        last_name = missing,
        last_update = missing,
 ) = (
            x = new(missing, missing, missing, missing);
            x.actor_id = actor_id;
            x.first_name = first_name;
            x.last_name = last_name;
            x.last_update = last_update;
            return x
            )

end
