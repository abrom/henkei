# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'henkei/version'

Gem::Specification.new do |spec|
  spec.name          = 'henkei'
  spec.version       = Henkei::VERSION
  spec.authors       = ['Erol Fornoles', 'Andrew Bromwich']
  spec.email         = ['erol.fornoles@gmail.com', 'a.bromwich@gmail.com']
  spec.description   = %q{Read text and metadata from files and documents (.doc, .docx, .pages, .odt, .rtf, .pdf)}
  spec.summary       = %q{Read text and metadata from files and documents (.doc, .docx, .pages, .odt, .rtf, .pdf)}
  spec.homepage      = 'http://github.com/abrom/henkei'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'mime-types', '>= 1.23'
  spec.add_runtime_dependency 'json', '>= 1.8'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.5'
end
