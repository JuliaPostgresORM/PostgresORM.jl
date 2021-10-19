# Getting started

## Pre-requisites
### Install LibPQ.jl
`(MyProject) pkg> add LibPQ`

### Install PostgresORM.jl
`(MyProject) pkg> add PostgresORM`

## Example projects
You can look at the following projects to see how PostgresORM is used :
  * [IMDBTestApp.jl](https://github.com/JuliaPostgresORM/IMDBTestApp.jl)


## Concepts

### Classes

PostgreSQL tables are mapped to mutable composite types that inherit the
abstract type PostgresORM.IEntity.

For the sake of conciseness we call this particular type a _class_.

A _class_ looks like this :

```
mutable struct Film <: IFilm

  id::Union{Missing,Int32}
  codeName::Union{Missing,String}
  year::Union{Missing,Int16}
  actorFilmAssos::Union{Missing,Vector{Model.IActorFilmAsso}}

  Film(args::NamedTuple) = Film(;args...)
  Film(;
    id = missing,
    codeName = missing,
    year = missing,
    actorFilmAssos = missing,
  ) = (
    x = new(missing,missing,missing,missing,);
    x.id = id;
    x.codeName = codeName;
    x.year = year;
    x.actorFilmAssos = actorFilmAssos;
    return x
  )

end
```

Lets describe the key aspects of a _class_:

#### A _class_ inherits an abstract type that inherits IEntity
`mutable struct Film <: IFilm` where `IFilm <: PostgresORM.IEntity`

This allows us to avoid circular dependencies

#### Fields of a class are all Union of a Missing and something else
`id::Union{Missing,Int32}`

The 'something else' can be a lot of things including a `IEntity` or a vector of
`IEntity`.

In this documentation we call:

A '_complex property_', a property of type `IEntity`. It is also named
a "manyToOne" property and it resolves to a foreign key in the table of the
  _class_.

A '_property of IEntities_', a property of type `Vector{T} where T <: IEntity`.  
It is also named a "oneToMany" property and it is the counter part of a
_complex property_ in another _class_.



#### A _class_ has two constructors

A first constructor that takes a NamedTuple and that is required by PostgresORM
function. It calls the second constructor by splatting the NamedTuple.

A second constructor that takes optional named arguments with default values
  `missing` and that assign the values to the matching properties.

Therefore:

Calling `Film()` creates an instance of _Film_ with all properties set
to `missing`

Calling `Film(id = 34, codeName = "cube")` creates an instance of _Film_
with all properties set to `missing` except _id_ and _codeName_

### ORM modules
An ORM module is a Julia module that tells PostgresORM how to handle a _class_.
It contains the following:

`data_type = Model.Film`: Assigns the module variable `data_type` to the
  _class_ associated with the ORM module

`PostgresORM.get_orm(x::Model.Film) = return(ORM.FilmORM)`: Declares a new
  method of function `PostgresORM.get_orm`, this function is used to tell
  PostgresORM which ORM module to use for a given _class_

`get_schema_name() = "public"`: Returns the PostgreSQL schema name of the
table associated with the _class_

`get_table_name() = "film"`: Returns the table name associated with the _class_  

`get_columns_selection_and_mapping()`: Returns the mapping between julia
  fields and table columns. Note that  a _complex property_ can be mapped to
  an array of columns if the foreign key has multiple columns (i.e. if the
  _class_ of the _complex_property_ has a composite id)

`get_id_props()`: Returns the fields that make the id of the _class_. These
  fields can be _complex properties_

`get_onetomany_counterparts()`: It gives for every _property of IEntities_  
  the associated _complex property_ (i.e. manyToOne property)

`get_types_override()`: It gives for every oneToMany or manyToOne property
  the real type of the property

__Some optional functions for the tracking of changes:__

`get_track_changes()`: Tells PostgresORM to record all the changes made to
  instances of the _class_

`get_creator_property()`: Tells which property holds the reference of the
  user that created the instance. This property must inherit `PostgresORM.AppUser`

`get_editor_property()`: Tells which property holds the reference of the
  user that last edited the instance. This property must inherit `PostgresORM.AppUser`

`get_creation_time_property()`: Tells which property holds the creation
  time of the instance

`get_update_time_property()`: Tells which property holds the last update
  time of the instance

### Enums
Julia enums are the counterpart of PostgreSQL custom enumeration types.

### LibPQ connection
Many PostgresORM functions expects a `LibPQ.Connection` as one of the arguments.
The developer is in charge of managing the connections and the transactions.

## Design choices

### Retrieval of _complex properties_
Methods `retrieve_entity` and `retrieve_one_entity` expects the argument
`retrieve_complex_props` to tell them if they need to make additional queries
to retrieve the properties of the _complex properties_.
If `retrieve_complex_props == false` then the properties of a _complex_property_
will be set to missing except the properties used as IDs.

### Retrieval of _properties of IEntities_
Reminder, methods `retrieve_entity` and `retrieve_one_entity` expects the argument
`retrieve_complex_props` to tell them if they need to make additional queries
to retrieve the properties of the  _complex properties_. There is no such thing
for _properties of IEntities_, PostgresORM never loads them (the properties of
will be equal to missing). It is up to the package user to enrich the instance
if he wants to.

### Update of a _properties of IEntities_
`update_entity` does not update properties of type vector of IEntities.
If the user wants to update a property of type vector of IEntities, he needs to
use `update_vector_property!`.

### Beware! missing has two meanings
A property with value missing can mean that:
  * the value is missing for this entity
  * the value has not been loaded yet

We could have make use of `Nothing` for the second case but we decided not to
because the benefit was too small compare to the complexity it was adding.
Nevertheless, the developer must be well aware of this when updating an instance.
Here are two code snippets to show what is the risk:

```
  # Load the film with retrieve_complex_props set to true
  film = retrieve_one_entity(Film(codeName = "cube"),
                             true, # retrieve the complex props
                             dbconn)
  @test ismissing(film.director.id) # false
  @test ismissing(film.director.birthDate) # false
  update_entity(film.director, dbconn) # This is OK


  # Load the film with retrieve_complex_props set to false
  film = retrieve_one_entity(Film(codeName = "cube"),
                             false, # do not retrieve the complex props
                             dbconn)
  @test ismissing(film.director.id) # false
  @test ismissing(film.director.birthDate) # true
  update_entity(film.director, dbconn) # This is NOT OK! the director will loose
                                       #   its birthDate


```

## Reverse engineer the database
The easiest way to get started is to ask PostgresORM to generate the _classes_,
the ORM modules and the enums. Once done, you can copy the files in the _src_
folder of the project and declare everything in the project
(see how it's done in
[IMDBTestApp.jl](https://github.com/JuliaPostgresORM/IMDBTestApp.jl)).

Here is an example of script to reverse engineer a database:

```
out_dir = (@__DIR__) * "/out"
dbconn = begin
    database = "imdbtestapp"
    user = "imdbtestapp"
    host = "127.0.0.1"
    port = "5432"
    password = "1234"

    LibPQ.Connection("host=$(host)
                      port=$(port)
                      dbname=$(database)
                      user=$(user)
                      password=$(password)
                      "; throw_error=true)
    end
PostgresORM.Tool.generate_julia_code(dbconn,out_dir)

close(dbconn)
```

## How to record changes

### Record the changes in the modified class itself
You can ask PostgresORM to record the following information inside the class itself :
  - the creator of an instance,
  - the last editor of an instance,
  - the creation time  of an instance,
  - the last edition time  of an instance

To do this you need to declare the following functions in the ORM of the class:
```
get_creator_property() = :your_creator_prop
get_editor_property() = :your_lastEditor_prop
get_creation_time_property() = :your_creationTime_prop
get_update_time_property() = :your_updateTime_prop
```

NOTE: You can decide to only declare some of these functions

### Record the changes in a 'modification' table

You can also ask PostgresORM to record the details of the modifications of a class
in a table.

To do this you need:
- Tell the ORM of the class that you want to record the changes
- A table where to write those modifications

#### Declare the following functions in the ORM of the class:
```
get_track_changes() = true
```

#### The `Modification` table

PostgresORM ships a class `Modification` that inherits from `IEntity`.
It also has the accompanying ORM mapping module `PostgresORM.ModificationORM`.
By default, this class is serialized to a table `modification` in the schema `public`.

Here is the SQL for the creation of the table if you want to use the default mapping of ModificationORM:

```
CREATE TABLE public.modification
(
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    entity_type character varying COLLATE pg_catalog."default",
    entity_id character varying COLLATE pg_catalog."default",
    attrname character varying COLLATE pg_catalog."default",
    oldvalue text COLLATE pg_catalog."default",
    user_id character varying COLLATE pg_catalog."default",
    newvalue text COLLATE pg_catalog."default",
    action_id uuid,
    action_type character varying(10) COLLATE pg_catalog."default",
    creation_time timestamp without time zone,
    CONSTRAINT modification_pkey PRIMARY KEY (id)
)
```

Suppose the modification table is in a different schema, you can tell PostgresORM where it is by overwriting the functions of `PostgresORM.ModificationORM`.
Eg.
```
PostgresORM.ModificationORM.get_schema_name() = "my_schema"
```
