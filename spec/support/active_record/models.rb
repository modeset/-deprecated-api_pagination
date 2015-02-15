class Item < ActiveRecord::Base
  include Api::Pagination::Simple
  include Api::Pagination::Timestamp
  include Api::Pagination::TimestampFilterable

  belongs_to :user
  has_many :likes
end

class Like < ActiveRecord::Base
  include Api::Pagination::Simple
  include Api::Pagination::Timestamp
  include Api::Pagination::TimestampFilterable

  belongs_to :user
  belongs_to :item
end

class User < ActiveRecord::Base
  include Api::Pagination::Simple
  include Api::Pagination::Timestamp
  include Api::Pagination::TimestampFilterable

  has_many :likes
  has_many :items
end
