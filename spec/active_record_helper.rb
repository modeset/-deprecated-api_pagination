require 'active_record'

# connect to an in memory db and create our table
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Base.connection.execute(<<-SQL)
  CREATE TABLE "items" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime, "updated_at" datetime)
SQL

# create the item factory
class Item < ActiveRecord::Base; end

# require support libraries
Dir[File.expand_path('../support/active_record/**/*.rb', __FILE__)].each { |f| require f }

# turn on active record logging if needed
ActiveRecord::Base.logger = Logger.new(STDOUT)

RSpec.configure do |config|

  # clean up our table after each spec
  config.after(:each) { ActiveRecord::Base.connection.execute('DELETE FROM "items"') }

end
