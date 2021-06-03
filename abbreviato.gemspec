# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'abbreviato/version'

Gem::Specification.new do |s|
  s.name = 'abbreviato'
  s.version = Abbreviato::VERSION

  s.authors = ['Jorge Manrubia']
  s.description = 'Truncate HTML to a specific bytesize, while keeping valid markup'
  s.email = 'jorge.manrubia@gmail.com'
  s.extra_rdoc_files = [
    'LICENSE.txt',
    'README.md'
  ]
  s.files = Dir['{app,config,db,lib}/**/*', 'LICENSE.txt', 'Rakefile', 'README.rdoc']
  s.homepage = 'https://github.com/zendesk/abbreviato'
  s.licenses = ['MIT']
  s.require_paths = ['lib']
  s.rubygems_version = '2.0.2'
  s.summary = 'A tool for efficiently truncating HTML strings to a specific bytesize'

  s.required_ruby_version = '>= 2.6.6'

  s.add_dependency 'htmlentities', '~> 4.3.4'
  s.add_dependency 'nokogiri', '1.11.7'

  s.add_development_dependency 'awesome_print'
  s.add_development_dependency 'benchmark-memory'
  s.add_development_dependency 'brakeman'
  s.add_development_dependency 'bump'
  s.add_development_dependency 'bundler-audit'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'flay'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-benchmark'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-rake'
  s.add_development_dependency 'rubocop-rspec'
end
