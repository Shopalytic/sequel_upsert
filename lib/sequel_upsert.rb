require 'sequel'
require 'sequel_upsert/version'
require 'sequel_upsert/upsert'

class Sequel::Dataset
  def upsert(selector_fields, setter_fields)
    up = SequelUpsert::Upsert.new(self, selector_fields, setter_fields)
    up.create_procedure
    up.execute
  end
end
