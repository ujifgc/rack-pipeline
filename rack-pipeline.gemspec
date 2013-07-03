# coding: utf-8
$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'rack-pipeline/version'

Gem::Specification.new do |spec|
  spec.name          = 'rack-pipeline'
  spec.version       = RackPipeline::VERSION
  spec.description   = 'Asset pipeline for ruby Rack'
  spec.summary       = 'A Rack middleware to serve javascript and stylesheet assets for ruby web applications'

  spec.authors       = ['Igor Bochkariov']
  spec.email         = ['ujifgc@gmail.com']
  spec.homepage      = 'https://github.com/ujifgc/rack-pipeline'
  spec.license       = 'MIT'

  spec.require_paths = ['lib']
  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^test/})

  spec.add_development_dependency 'bundler', '>= 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
end
