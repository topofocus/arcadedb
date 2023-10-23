
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'arcade/version'
Gem::Specification.new do |spec|
  spec.name          = "arcadedb"
  spec.version       = Arcade::VERSION
  spec.author        = "Hartmut Bischoff"
  spec.email         = "topofocus@gmail.com"
  spec.license       = 'MIT'
  spec.summary       = %q{Ruby Interface to ArcadeDB}
  spec.description   = %q{Provides access to ArcadeDB from ruby}
  spec.homepage      = "https://github.com/topofocus/arcadedb"


  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 4.0"
  #	'activesupport', '>= 6.0'
#	spec.add_dependency 'activemodel'
  spec.add_dependency "httpx"
  spec.add_dependency 'dry-schema'
  spec.add_dependency 'dry-struct'
  spec.add_dependency 'dry-core'
  spec.add_dependency 'dry-configurable'
  spec.add_dependency 'dry-monads'
  ## Database-Access via Postgres is not implemented
#	spec.add_dependency 'pg'
#	spec.add_dependency 'mini_sql'
end
