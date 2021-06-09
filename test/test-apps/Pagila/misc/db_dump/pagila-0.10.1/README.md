# Pagila

## HOWTO Create the database and insert the data

### Create user and database

As user postgres:
```
CREATE USER pagila PASSWORD 'XXXXXXX';
CREATE DATABASE pagila OWNER pagila;
```

### Create the schema insert the data
Execute the script for creating the schema and the inserting the data
```
psql -f  /home/myuser/CODE/PostgresDAO.jl/test/test-apps/Pagila.jl/misc/db_dump/pagila-0.10.1/pagila-schema.sql -d pagila
psql -f  /home/myuser/CODE/PostgresDAO.jl/test/test-apps/Pagila.jl/misc/db_dump/pagila-0.10.1/pagila-data.sql -d pagila
```
### Change the enums

```
ALTER TYPE mpaa_rating ADD VALUE 'PG13';
ALTER TYPE mpaa_rating ADD VALUE 'NC17';

update film set rating =  'PG13' WHERE rating = 'PG-13';
update film set rating =  'NC17' WHERE rating = 'NC-17';
```

### Simplify the model

Drop payment so that we do not have any FK to 'inventory'
```
drop table payment CASCADE;
```

### Add a composed foreign key

Add a composed foreign key so that we can test some scenarios involving a composed foreign key

```
ALTER TABLE public.film_actor
    ADD COLUMN film_release_year integer;

UPDATE film_actor
SET film_release_year = f.release_year
FROM film f WHERE film_actor.film_id = f.film_id
```

### Change the PK of film and update the corresponding FKs

Update the PK:
```
ALTER TABLE film DROP CONSTRAINT film_pkey CASCADE;
--NOTICE:  drop cascades to 2 other objects
--DETAIL:  drop cascades to constraint film_category_film_id_fkey on table film_category
--         drop cascades to constraint inventory_film_id_fkey on table inventory

ALTER TABLE film ADD PRIMARY KEY (film_id, release_year);

```

Update the PK and FK of 'film_actor':
```
ALTER TABLE ONLY film_actor DROP CONSTRAINT film_actor_pkey;
ALTER TABLE ONLY film_actor DROP CONSTRAINT film_actor_film_id_fkey;
ALTER TABLE film_actor ADD PRIMARY KEY (actor_id,film_id, film_release_year);

ALTER TABLE ONLY film_actor
    ADD CONSTRAINT film_actor_film_release_year_fkey
    FOREIGN KEY (film_id,film_release_year) REFERENCES film(film_id,release_year)  ON UPDATE CASCADE ON DELETE RESTRICT;

```


Update the PK and FK of 'film_category':
```

ALTER TABLE public.film_category
    ADD COLUMN film_release_year integer;

UPDATE film_category
SET film_release_year = f.release_year
FROM film f WHERE film_category.film_id = f.film_id;

ALTER TABLE ONLY film_category DROP CONSTRAINT film_category_pkey;
ALTER TABLE film_category ADD PRIMARY KEY (category_id, film_id, film_release_year);

ALTER TABLE ONLY film_category
    ADD CONSTRAINT film_category_film_release_year_fkey
    FOREIGN KEY (film_id,film_release_year) REFERENCES film(film_id,release_year)  ON UPDATE CASCADE ON DELETE RESTRICT;

```


Update the PK and FK of 'inventory':
```

ALTER TABLE public.inventory
    ADD COLUMN film_release_year integer;

UPDATE inventory
    SET film_release_year = f.release_year
    FROM film f WHERE inventory.film_id = f.film_id;

ALTER TABLE ONLY inventory DROP CONSTRAINT inventory_pkey CASCADE;
-- NOTICE:  drop cascades to constraint rental_inventory_id_fkey on table rental

ALTER TABLE inventory ADD PRIMARY KEY (inventory_id, film_id, film_release_year);

ALTER TABLE ONLY inventory
    ADD CONSTRAINT inventory_film_release_year_fkey
    FOREIGN KEY (film_id,film_release_year) REFERENCES film(film_id,release_year)  ON UPDATE CASCADE ON DELETE RESTRICT;

```

### Add the modification table for tracking changes

As user postgres:
`CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`

As user pagila:

```
CREATE TABLE public.modification
(
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    entity_type character varying ,
    entity_id character varying ,
    attrname character varying ,
    oldvalue text ,
    user_id character varying ,
    newvalue text ,
    action_id uuid,
    action_type character varying(10) ,
    creation_time timestamp without time zone,
    CONSTRAINT modification_pkey PRIMARY KEY (id)
)
```


## NOTES about this database

Pagila is a port of the Sakila example database available for MySQL, which was
originally developed by Mike Hillyer of the MySQL AB documentation team. It
is intended to provide a standard schema that can be used for examples in
books, tutorials, articles, samples, etc.

All the tables, data, views, and functions have been ported; some of the changes made were:

* Changed char(1) true/false fields to true boolean fields
* The last_update columns were set with triggers to update them
* Added foreign keys
* Removed 'DEFAULT 0' on foreign keys since it's pointless with real FK's
* Used PostgreSQL built-in fulltext searching for fulltext index.  Removed the need for the
  film_text table.
* The rewards_report function was ported to a simple SRF

The schema and data for the Sakila database were made available under the BSD license
which can be found at http://www.opensource.org/licenses/bsd-license.php. The pagila
database is made available under this license as well.


FULLTEXT SEARCH
---------------

In older versions of pagila, the fulltext search capabilities were split into a
seperate file, so they could be loaded into only databases that support fulltext.
Starting in PostgreSQL 8.3, fulltext functionality is built in, so now these
parts of the schema exist in the main schema file.

Example usage:

SELECT * FROM film WHERE fulltext @@ to_tsquery('fate&india');


PARTITIONED TABLES
------------------

The payment table is designed as a partitioned table with a 6 month timespan for the date ranges.
If you want to take full advantage of table partitioning, you need to make sure constraint_exclusion
is turned on in your database. You can do this by setting "constraint_exclusion = on" in your
postgresql.conf, or by issuing the command "ALTER DATABASE pagila SET constraint_exclusion = on"
(substitute pagila for your database name if installing into a database with a different name)


INSTALL NOTE
------------

The pagila-data.sql file and the pagila-insert-data.sql both contain the same
data, the former using COPY commands, the latter using INSERT commands, so you
only need to install one of them. Both formats are provided for those who have
trouble using one version or another.


ARTICLES
--------------

The following articles make use of pagila to showcase various PostgreSQL features:

* Showcasing REST in PostgreSQL - The PreQuel
http://www.postgresonline.com/journal/index.php?/archives/32-Showcasing-REST-in-PostgreSQL-The-PreQuel.html#extended

* PostgreSQL 8.3 Features: Enum Datatype
http://people.planetpostgresql.org/xzilla/index.php?/archives/320-PostgreSQL-8.3-Features-Enum-Datatype.html

* Email Validation with pl/PHP
http://people.planetpostgresql.org/xzilla/index.php?/archives/261-Re-inventing-Gregs-method-to-prevent-re-inventing.html

* Getting Started with PostgreSQL for Windows
http://www.charltonlopez.com/index.php?option=com_content&task=view&id=56&Itemid=38

* RATIO_TO_REPORT in PostgreSQL
http://people.planetpostgresql.org/xzilla/index.php?/search/pagila/P3.html

* The postmaster and postgres Processes
http://www.charltonlopez.com/index.php?option=com_content&task=view&id=57&Itemid=38

* Building Rails to Legacy Applications :: Take Control of Active Record
http://people.planetpostgresql.org/xzilla/index.php?/archives/220-Building-Rails-to-Legacy-Applications-Take-Control-of-Active-Record.html

* Building Rails to Legacy Applications :: Masking the Database
http://people.planetpostgresql.org/xzilla/index.php?/archives/213-Building-Rails-to-Legacy-Applications-Masking-the-Database.html


VERSION HISTORY
---------------

Version 0.10.1
* Add pagila-data-insert.sql file, added articles section

Version 0.10
* Support for built-in fulltext. Add enum example

Version 0.9
* Add table partitioning example

Version 0.8
* First release of pagila
