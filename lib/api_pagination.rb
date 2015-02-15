require 'api_pagination/version'
require 'api_pagination/common_interface'

module Api::Pagination
  autoload :Simple, 'api_pagination/active_record/simple'
  autoload :Timestamp, 'api_pagination/active_record/timestamp'
  autoload :TimestampFilterable, 'api_pagination/active_record/timestamp_filterable'

  class MissingFilterMethodError < StandardError
    def initialize(value)
      super [
        "Missing filter or no filter provided,",
        "expected #{value} to respond to filtered? or to have a filter option provided.",
      ].join(' ')
    end
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
