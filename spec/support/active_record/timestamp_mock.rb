class TimestampMock < ActiveRecord::Base
  include Api::Pagination::Timestamp
  self.table_name = 'items'
end
