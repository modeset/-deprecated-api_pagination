require 'api_pagination/version'
require 'api_pagination/common_interface'

require 'api_pagination/simple'
require 'api_pagination/timestamp'

module Api::Pagination
  class InvalidTimestampError < StandardError
    def initialize(value)
      super [
        "Invalid time value #{value.inspect},",
        "expected string matching #{Api::Pagination::Timestamp::TIMESTAMP_FORMAT}."
      ].join(' ')
    end
  end

end
