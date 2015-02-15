require 'active_record'

# connect to an in memory db and create our table
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Base.connection.execute(<<-SQL)
  CREATE TABLE "items" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "user_id" integer,
    "title" string,
    "active" boolean,
    "disabled" boolean,
    "created_at" datetime,
    "updated_at" datetime
  )
SQL
ActiveRecord::Base.connection.execute(<<-SQL)
  CREATE TABLE "likes" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "user_id" integer,
    "item_id" integer,
    "created_at" datetime
  )
SQL
ActiveRecord::Base.connection.execute(<<-SQL)
  CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "name" string,
    "created_at" datetime
  )
SQL

# require support libraries
Dir[File.expand_path('../support/active_record/**/*.rb', __FILE__)].each { |f| require f }

RSpec.configure do |config|

  config.before(:each) do
    # turn on active record logging if needed
    # ActiveRecord::Base.logger = Logger.new(STDOUT)
  end

  # clean up our table after each spec
  config.after(:each) do
    # turn on active record logging if needed
    ActiveRecord::Base.logger = nil
    ActiveRecord::Base.connection.execute(<<-SQL)
      DELETE FROM "items";
      DELETE FROM "likes";
      DELETE FROM "users";
    SQL
  end

end
