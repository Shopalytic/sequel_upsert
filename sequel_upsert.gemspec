require File.expand_path('../lib/sequel_upsert/version', __FILE__)

Gem::Specification.new do |s|
  s.name = "sequel_upsert"
  s.version = SequelUpsert::VERSION
  s.author = "Adam Gotterer"
  s.email = "adam@shopalytic.com"
  s.platform = Gem::Platform::RUBY
  s.summary = "Sequel upsert support for PostgreSQL"
  s.files = Dir.glob("{lib}/**/*") + %w(README.md MIT-LICENSE)
  s.test_files = Dir.glob("{spec}/**/*")
  s.require_paths = ['lib']
  s.license = 'MIT'
  s.homepage = 'https://github.com/Shopalytic/sequel_upsert'
  s.rdoc_options = ['--inline-source', '--line-numbers', '--title', 'Sequel Upsert: Upsert suport for postgres through sequel', 'README', 'MIT-LICENSE', 'lib']
  s.add_dependency('sequel')
  s.required_ruby_version = '>= 1.9.2'
  s.add_development_dependency 'rspec', '>= 1.2.9'
end
