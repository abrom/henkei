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
  spec.homepage      = 'https://github.com/abrom/henkei'
  spec.license       = 'MIT'
  spec.required_ruby_version = ['>= 3.2.0', '< 4.0.0']

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.' unless spec.respond_to?(:metadata)

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = `git ls-files`.split("\n")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'json', '>= 1.8', '< 3'
  spec.add_dependency 'mini_mime', '>= 0.1.1', '< 2'
end
