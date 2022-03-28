# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'henkei/version'

Gem::Specification.new do |spec| # rubocop:disable Metrics/BlockLength
  spec.name          = 'henkei'
  spec.version       = Henkei::VERSION
  spec.authors       = ['Erol Fornoles', 'Andrew Bromwich']
  spec.email         = %w[erol.fornoles@gmail.com a.bromwich@gmail.com]
  spec.description   = 'Read text and metadata from files and documents using Apache Tika toolkit'
  spec.summary       = 'Read text and metadata from files and documents ' \
                       '(.doc, .docx, .pages, .odt, .rtf, .pdf) using Apache Tika toolkit'
  spec.homepage      = 'https://github.com/abrom/henkei'
  spec.license       = 'MIT'
  spec.required_ruby_version = ['>= 2.6.0', '< 3.2.0']

  spec.files         = `git ls-files`.split("\n")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'json', '>= 1.8', '< 3'
  spec.add_runtime_dependency 'mini_mime', '>= 0.1.1', '< 2'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'nokogiri', '~> 1.12'
  spec.add_development_dependency 'rails', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'rspec', '~> 3.7'
  spec.add_development_dependency 'rubocop', '~> 1.26'
  spec.add_development_dependency 'rubocop-performance', '~> 1.13'
  spec.add_development_dependency 'rubocop-rails', '~> 2.14'
  spec.add_development_dependency 'rubocop-rake', '~> 0.6'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.9'
  spec.add_development_dependency 'simplecov', '~> 0.15', '< 0.18'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
