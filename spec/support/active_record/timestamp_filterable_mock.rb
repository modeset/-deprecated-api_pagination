class TimestampFilterableRawMock < ActiveRecord::Base
  include Api::Pagination::TimestampFilterable
  self.table_name = 'items'

  scope :active, -> { where(active: true) }

  # filter proc
  FILTER = ->(record) { record.disabled? }

  # filter class
  class Filter
    def call(record)
      !(record.name =~ /^unfiltered/)
    end
  end
end

class TimestampFilterableMock < TimestampFilterableRawMock
  # filter method
  def filtered?
    disabled? || name =~ /^filtered/
  end
end
