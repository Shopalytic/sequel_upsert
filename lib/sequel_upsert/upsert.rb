require 'digest'

module SequelUpsert
  NAME_PREFIX = "upsert_#{ VERSION.gsub('.', '_') }"
  MAX_NAME_LENGTH = 62
  SEL_POSTFIX = '_sel'
  SET_POSTFIX = '_set'

  class Upsert
    attr_reader :selector_fields, :setter_fields, :table_name, :db, :dataset,
      :column_definitions

    def initialize(dataset, selector_fields, setter_fields)
      raise ArgumentError, '"selector_fields" must be a hash' unless selector_fields.is_a?(Hash)
      raise ArgumentError, '"setter_fields" must be a hash' unless setter_fields.is_a?(Hash)

      # Order matters when we generate a unique name
      @selector_fields = Hash[selector_fields.sort]
      @setter_fields = Hash[setter_fields.sort]

      @dataset = dataset
      @db = dataset.db

      if dataset.first_source.is_a?(Sequel::SQL::QualifiedIdentifier)
        @table_name = "#{ dataset.first_source.column }__#{ dataset.first_source.table }"
      else
        @table_name = dataset.first_source.to_s
      end

      @column_definitions = db.schema(@table_name.to_sym)
    end

    def set_name(field, postfix)
      "#{ field.to_s }#{ postfix }"
    end

    def unique_name
      parts = [
        NAME_PREFIX,
        table_name,
        'sel',
        selector_fields.keys.join('_a_'),
        'set',
        setter_fields.keys.join('_a_')
      ].join('_')

      if parts.length > MAX_NAME_LENGTH
        [NAME_PREFIX, table_name, Digest::MD5.hexdigest(parts)].join('_')
      else
        parts
      end
    end

    def set_sel_names
      Hash[selector_fields.map { |k, v| [k, Sequel.lit(set_name(k, SEL_POSTFIX))] }]
    end

    def set_set_names
      Hash[setter_fields.map { |k, v| [k, Sequel.lit(set_name(k, SET_POSTFIX))] }]
    end

    def column_type(field)
      column_definitions.find { |c| c[0] == field }[1][:db_type].upcase
    end

    def setter_function_definitions
      setter_fields.map { |k, v| set_name(k, SET_POSTFIX) + ' ' + column_type(k) }
    end

    def selector_function_definitions
      selector_fields.map { |k, v| set_name(k, SEL_POSTFIX) + ' ' + column_type(k) }
    end

    def create_procedure
      first_try = true

      db.run(%{
        CREATE OR REPLACE FUNCTION #{ unique_name } (#{ (setter_function_definitions + selector_function_definitions).join(', ') }) RETURNS VOID AS
        $$
        DECLARE
          first_try INTEGER := 1;
        BEGIN
          LOOP
            -- first try to update the key
            #{ dataset.where(set_sel_names).update_sql(set_set_names) };
            IF found THEN
                RETURN;
            END IF;
            -- not there, so try to insert the key
            -- if someone else inserts the same key concurrently,
            -- we could get a unique-key failure
            BEGIN
                #{ dataset.insert_sql(set_sel_names.merge(set_set_names)) };
                RETURN;
            EXCEPTION WHEN unique_violation THEN
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
      })

      self
    rescue
      if first_try and $!.message =~ /tuple concurrently updated/
        first_try = false
        retry
      else
        raise $!
      end
    end # / create_procedure

    def execute
      sel = Sequel.function(unique_name, *setter_fields.values, selector_fields.values)
      db.select { sel }.first
    end

    def self.clear_all_procedures(conn)
      # http://stackoverflow.com/questions/7622908/postgresql-drop-function-without-knowing-the-number-type-of-parameters
      conn.run(%{
        CREATE OR REPLACE FUNCTION pg_temp.upsert_delfunc(text)
          RETURNS void AS
        $BODY$
        DECLARE
          _sql text;
        BEGIN
        FOR _sql IN
          SELECT 'DROP FUNCTION ' || quote_ident(n.nspname)
                            || '.' || quote_ident(p.proname)
                            || '(' || pg_catalog.pg_get_function_identity_arguments(p.oid) || ');'
          FROM   pg_catalog.pg_proc p
          LEFT   JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
          WHERE  p.proname = $1
          AND    pg_catalog.pg_function_is_visible(p.oid) -- you may or may not want this
        LOOP
          EXECUTE _sql;
        END LOOP;
        END;
        $BODY$
          LANGUAGE plpgsql;
      })
      func_res = conn[:pg_proc]
        .select(:proname)
        .where(Sequel.like(:proname, "#{ NAME_PREFIX }%"))

      func_res.each do |row|
        next if row[:proname] == 'upsert_delfunc'
        conn.run %{SELECT pg_temp.upsert_delfunc('#{ row[:proname] }')}
      end
    end
  end
end
