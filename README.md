Making changes!

# Sequel Upsert

Adds upsert support to Sequel when used with PostgreSQL. The code is highly influenced by [https://github.com/seamusabshere/upsert](https://github.com/seamusabshere/upsert) but has been re-written to integrate cleanly with Sequel and be accessible from Sequel::Dataset.

Transparently creates (and re-uses) stored procedures/functions which is significantly faster then upsert support written entirely in code.

Tested on Ruby 2.0 MRI. Expected to work on 1.9.3.

## Usage

`upsert` takes a selector hash and setters hash

```ruby
# Inserts a new record and creates a stored procedure that handles similar upsert requests
DB[:users].upsert({ username: 'shopalytic' }, { color: 'green' })

# Updates the previously inserted record color to blue
DB[:users].upsert({ username: 'shopalytic' }, { color: 'blue' })
```

#### SQL MERGE trick

Adapted from the [canonical PostgreSQL upsert example](http://www.postgresql.org/docs/current/interactive/plpgsql-control-structures.html#PLPGSQL-ERROR-TRAPPING):

```sql
CREATE OR REPLACE FUNCTION upsert_pets_SEL_name_A_tag_number_SET_name_A_tag_number("name_sel" character varying(255), "tag_number_sel" integer, "name_set" character varying(255), "tag_number_set" integer) RETURNS VOID AS
$$
DECLARE
  first_try INTEGER := 1;
BEGIN
  LOOP
    -- first try to update the key
    UPDATE "pets" SET "name" = "name_set", "tag_number" = "tag_number_set"
      WHERE "name" = "name_sel" AND "tag_number" = "tag_number_sel";
    IF found THEN
      RETURN;
    END IF;
    -- not there, so try to insert the key
    -- if someone else inserts the same key concurrently,
    -- we could get a unique-key failure
    BEGIN
      INSERT INTO "pets"("name", "tag_number") VALUES ("name_set", "tag_number_set");
      RETURN;
    EXCEPTION WHEN unique_violation THEN
      -- seamusabshere 9/20/12 only retry once
      IF (first_try = 1) THEN
        first_try := 0;
      ELSE
        RETURN;
      END IF;
      -- Do nothing, and loop to try the UPDATE again.
    END;
  END LOOP;
END;
$$
LANGUAGE plpgsql;
```

## Gotchas

- Currently there is no support for hstore

## Copyright

Copyright 2014 Shopalytic, Inc.
