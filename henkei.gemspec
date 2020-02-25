# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'henkei/version'

Gem::Specification.new do |spec|
  spec.name          = 'henkei'
  spec.version       = Henkei::VERSION
  spec.authors       = ['Erol Fornoles', 'Andrew Bromwich']
  spec.email         = %w[erol.fornoles@gmail.com a.bromwich@gmail.com]
  spec.description   = 'Read text and metadata from files and documents using Apache Tika toolkit'
  spec.summary       = 'Read text and metadata from files and documents ' \
                       '(.doc, .docx, .pages, .odt, .rtf, .pdf) using Apache Tika toolkit'
  spec.homepage      = 'http://github.com/abrom/henkei'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split("\n")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'json', '>= 1.8', '< 3'
  spec.add_runtime_dependency 'mime-types', '>= 1.23', '< 4'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rails', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'rspec', '~> 3.7'
  spec.add_development_dependency 'rubocop', '~> 0.71'
  spec.add_development_dependency 'simplecov', '~> 0.15'
end
