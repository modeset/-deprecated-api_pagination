require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'api_pagination'

RSpec.configure do |config|
  config.order = 'random'
  config.run_all_when_everything_filtered = true
end

# require support libraries
Dir[File.expand_path('../support/*.rb', __FILE__)].each { |f| require f }
