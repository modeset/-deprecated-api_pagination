class TimestampFilterableMock < ActiveRecord::Base
  include Api::Pagination::TimestampFilterable
  self.table_name = 'items'

  scope :active, -> { where(active: true) }

  # filter method
  def filtered?
    disabled? || name =~ /^filtered/
  end

  # filter proc
  FILTER = ->(record) { record.disabled? }

  # filter class
  class Filter
    def call(record)
      !(record.name =~ /^unfiltered/)
    end
  end
end

