Gem::Specification.new do |s|
  s.name = "sequel_upsert"
  s.version = "1.0.0"
  s.author = "Adam Gotterer"
  s.email = "adam@shopalytic.com"
  s.platform = Gem::Platform::RUBY
  s.summary = "Upsert support"
  s.files = %w'README MIT-LICENSE lib/sequel_postgresql_triggers.rb spec/sequel_postgresql_triggers_spec.rb'
  s.license = 'MIT'
  s.homepage = 'https://github.com/jeremyevans/sequel_postgresql_triggers'
  s.rdoc_options = ['--inline-source', '--line-numbers', '--title', 'Sequel Upsert: Upsert suport for postgres through sequel', 'README', 'MIT-LICENSE', 'lib']
  s.add_dependency('sequel')
end
