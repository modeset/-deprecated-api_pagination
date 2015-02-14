$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'api_pagination/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'api_pagination'
  s.version     = Api::Pagination::VERSION
  s.authors     = ['jejacks0n']
  s.email       = ['info@modeset.com']
  s.homepage    = 'https://github.com/modeset/api_pagination'
  s.summary     = 'Api::Pagination: An API pagination service layer'
  s.description = 'Easy pagination for ActiveRecord collections using a common interface'
  s.license     = 'MIT'

  s.files       = Dir['{lib}/**/*'] + ['MIT.LICENSE', 'README.md']
  s.test_files  = `git ls-files -- {spec,test}/*`.split("\n")
end
