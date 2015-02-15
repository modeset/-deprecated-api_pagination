require 'api_pagination/version'
require 'api_pagination/common_interface'

module Api::Pagination
  autoload :Simple, 'api_pagination/simple'
  autoload :Timestamp, 'api_pagination/timestamp'
  autoload :TimestampFilterable, 'api_pagination/timestamp_filterable'

  class MissingFilterMethodError < StandardError
  end

  class InvalidTimestampError < StandardError
    def initialize(value)
      super [
        "Invalid time value #{value.inspect},",
        "expected string matching #{Api::Pagination::Timestamp::TIMESTAMP_FORMAT}."
      ].join(' ')
    end
  end
end
