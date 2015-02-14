class SimpleMock < ActiveRecord::Base
  include Api::Pagination::Simple
  self.table_name = 'items'
end
