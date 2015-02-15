require 'api_pagination/version'
require 'api_pagination/common_interface'

require 'api_pagination/simple'
require 'api_pagination/timestamp'
require 'api_pagination/timestamp_filterable'

module Api::Pagination
  class MissingFilterMethodError < StandardError; end
  class InvalidTimestampError < StandardError
    def initialize(value)
      super [
        "Invalid time value #{value.inspect},",
        "expected string matching #{Api::Pagination::Timestamp::TIMESTAMP_FORMAT}."
      ].join(' ')
    end
  end
end
