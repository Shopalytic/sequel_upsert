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
      String :size
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
  end

  describe '#initialize' do
    it "raises ArgumentError when selector_fields isn't a hash" do
      expect{ upsert('invalid', {}) }.to raise_error(ArgumentError, '"selector_fields" must be a hash')
    end

    it "raises ArgumentError when setter_fields isn't a hash" do
      expect{ upsert({}, 'invalid') }.to raise_error(ArgumentError, '"setter_fields" must be a hash')
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

  describe '#column_type' do
    it 'finds the db type of a column' do
      up = upsert({ username: 'testing' }, {})
      up.column_type(:username).should == 'TEXT'
    end
  end
end
