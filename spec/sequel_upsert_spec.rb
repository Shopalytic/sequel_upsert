#!/usr/bin/env spec
require 'rubygems'
require 'sequel'

DB = Sequel.connect(ENV['SEQUEL_UPSERT_SPEC_DB'] || 'postgres:///upsert?user=vagrant&password=vagrant')

$:.unshift(File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), 'lib'))
require 'sequel_upsert'


describe 'Sequel Upsert' do
  before do
    DB.create_table(:users) do
      String :username, unique: true
      String :color
      String :size, default: 'large'
      Integer :counter, default: 1
    end
  end

  after do
    DB.drop_table :users
    SequelUpsert::Upsert.clear_all_procedures(DB)
  end

  let(:procs) {
    DB[:pg_proc]
      .where(Sequel.like(:proname, 'upsert%'))
      .where(Sequel.~({ proname: 'upsert_delfunc' }))
  }

  def upsert(sel, set)
    SequelUpsert::Upsert.new(DB[:users], sel, set)
  end

  describe 'Sequel::Dataset#upsert' do
    it 'should insert a new record' do
      DB[:users].upsert({ username: 'testing' }, { color: 'green' })

      DB[:users].count.should == 1
      row = DB[:users].first
      row[:username].should == 'testing'
      row[:color].should == 'green'
    end

    it 'should update the color to green and the size to small' do
      DB[:users] << { username: 'testing', color: 'blue', size: 'medium'}
      DB[:users].upsert({ username: 'testing' }, { color: 'green', size: 'small' })

      DB[:users].count.should == 1
      row = DB[:users].first
      row[:username].should == 'testing'
      row[:color].should == 'green'
      row[:size].should == 'small'
    end

    it 'should force a default value' do
      DB[:users].upsert({ username: 'testing' }, { color: 'green', size: Sequel.lit('default') })

      row = DB[:users].first
      row[:size].should == 'large'
    end

    it 'sets a solumn that already exists back to the default' do
      DB[:users].upsert({ username: 'testing' }, { size: 'medium' })
      DB[:users].upsert({ username: 'testing' }, { color: 'green', size: Sequel.lit('default') })

      row = DB[:users].first
      row[:size].should == 'large'
    end
  end

  describe '#initialize' do
    it "raises ArgumentError when selector_fields isn't a hash" do
      expect{ upsert('invalid', {}) }.to raise_error(ArgumentError, '"selector_fields" must be a hash')
    end

    it "raises ArgumentError when setter_fields isn't a hash" do
      expect{ upsert({}, 'invalid') }.to raise_error(ArgumentError, '"setter_fields" must be a hash')
    end

    context 'table_name' do
      it 'sets from a symbol' do
        upsert({}, {}).table_name.should == 'users'
      end

      it 'accepts a QualifiedIdentifier with a schema and table' do
        SequelUpsert::Upsert.new(DB[Sequel.qualify(:public, :users)], {}, {}).table_name.should == 'public__users'
      end
    end
  end

  describe '#create_procedure' do
    it 'creates the stored procedure' do
      upsert({ username: 'testing' }, { color: 'green', size: 'small' }).create_procedure

      procs.count.should == 1
      procs.first[:proname].should include('users_sel_username_set_color_a_size')
    end

    it 'should only create one stored procedure when the param order changes' do
      upsert({ username: 'testing' }, { color: 'green', size: 'small' }).create_procedure
      upsert({ username: 'testing' }, { size: 'small', color: 'green' }).create_procedure

      procs.count.should == 1
    end

    it 'creates multiple stored procedures when the params are different' do
      upsert({ username: 'testing' }, { size: 'small' }).create_procedure
      upsert({ username: 'testing' }, { size: 'small', color: 'green' }).create_procedure

      procs.count.should == 2
    end
  end

  describe '#column_definition' do
    it 'finds the db type of a column' do
      up = upsert({ username: 'testing' }, {})
      column = up.column_definition(:size)
      column[:db_type].should == 'text'
      column[:ruby_default].should == 'large'
    end

    it 'raises IndexError when field is not in the definition list' do
      up = upsert({ username: 'testing' }, {})
      expect { up.column_definition(:not_found) }.to_raise(IndexError, 'not_found not found in the column definition list')
    end
  end

  describe '#unique_name' do
    it 'sets the name' do
      up = upsert({ username: 'testing' }, { color: 'green', size: 'small' })
      up.unique_name.should include('users_sel_username_set_color_a_size')
    end

    it 'sets the name to an md5 when its greater then MAX_NAME_LENGTH' do
      up = upsert({ field1: 1, field2: 2, field3: 3 }, { field: 1, field2: 2, field3: 3, field4: 4, field5: 5, field6: 6 })
      up.unique_name.should match /upsert_(\d+)_(\d+)_(\d+)_(\w+){16}/
    end
  end
end
