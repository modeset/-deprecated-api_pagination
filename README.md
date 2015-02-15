Api::Pagination
===============

[![Gem Version](https://img.shields.io/gem/v/api_pagination.svg)](http://badge.fury.io/rb/api_pagination)
[![Build Status](https://img.shields.io/travis/modeset/api_pagination.svg)](https://travis-ci.org/modeset/api_pagination)
[![Code Climate](https://codeclimate.com/repos/54df9005e30ba012930060e4/badges/e466695e9c8859eaafd2/gpa.svg)](https://codeclimate.com/repos/54df9005e30ba012930060e4/feed)
[![Test Coverage](https://codeclimate.com/repos/54df9005e30ba012930060e4/badges/e466695e9c8859eaafd2/coverage.svg)](https://codeclimate.com/repos/54df9005e30ba012930060e4/feed)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)
[![Dependency Status](https://gemnasium.com/modeset/api_pagination.svg)](https://gemnasium.com/modeset/api_pagination)

Api::Pagination is a collection of pagination modules that follow a consistent interface so paginated items can be
referred to throughout your application in consistent terms. This was born from the need for more complex pagination
and wanting to provide consistent summaries of the pagination results.

## Table of Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Usage](#usage)

## Installation

Add it to your Gemfile:
```ruby
gem 'api_pagination'
```

And then execute:
```shell
$ bundle
```

Or install it yourself as:
```shell
$ gem install chewy
```


## Configuration

You can feel free to configure all pagination modules at once, or focus on specific ones. This is the basic
configuration that's provided by default.

```
Api::Pagination.configure do |config|
  # configure all pagination modules
  config.per_page_default 25 # default per page
  config.per_page_max 100 # maximum limit for per page values
  config.timestamp_format '%Y-%m-%dT%H:%M:%S.%N%z' # format for query params
  config.pessimistic_multiplier 2 # eager load (per page * 2) before filtering

  # configure only the simple module
  config.simple do |c|
    c.per_page_default 25 # default per page
    c.per_page_max 100 # maximum limit for per page values
  end

  # configure only the timestamp module
  config.timestamp do |c|
    c.per_page_default 25 # default per page
    c.per_page_max 100 # maximum limit for per page values
    c.timestamp_format '%Y-%m-%dT%H:%M:%S.%N%z' # format for query params
  end

  # configure only the timestamp filterable module
  config.timestamp_filterable do |c|
    c.per_page_default 25 # default per page
    c.per_page_max 100 # maximum limit for per page values
    c.timestamp_format '%Y-%m-%dT%H:%M:%S.%N%z' # format for query params
    c.pessimistic_multiplier 2 # eager load (per page * 2) before filtering
  end
end
```


## Usage

### Pagination Scopes

#### Simple

This is your basic page by number implementation that we're all familiar with. You can mix it with your own scopes, ask
for a given page, and additionally specify how many results per page.

```ruby
class Item < ActiveRecord::Base
  include Api::Pagination::Simple
end

# 25 records, starting at page 1, natural order
@items = Item.page

# 5 records, starting at page 2, ordered by created_at ASC
@items = Item.order(:created_at).page(2).per(5)

# 100 records, starting at page 3
@items = Item.page(page: 3, per_page: 100)
```

Once you've called a pagination scope, you can begin asking questions about its results. These are mixed into the scope
chain directly, and so you can call methods on the scope itself. In these examples, we assume we have 23 records, and
have asked for page 3 with 5 per page.

```ruby
@items.paginatable? # => true, if you've used the `page` scope at all.

@items.total_count # => 23 - how many total records there are to page through.
@items.total_pages # => 5 - the total number of pages.
@items.total_pages_remaining # 2 - the number of pages remaining.

@items.first_page? # false - boolean, if it's on the first page or not.
@items.last_page? # false - boolean, if it's on the last page or not.
```

Additionally, you can get the various values to continue loading pages. For instance, you can get the page value for
the first, last, next, and previous pages.

```ruby
@items.first_page_value # => 1 - in the simple paginator, this will always be 1
@items.last_page_value # => 5 - page 5 would only load 3 records
@items.prev_page_value # => 2
@items.next_page_value # => 4
```

#### Timestamp

Paging by timestamps is a more robust way to paginate records when content could be added between page requests. For any
real-time, or partial real-time case this is probably the pagination method you'll want to use the most.

One of the challenges faced with the simple number pagination is that if a new record is added, records already seen can
be duplicated in subsequent page requests. An example of this is listing items from newest to oldest -- if a new item is
created after loading page 1 but before page 2 has been loaded -- page 2 will now include the last item(s) from page 1.

Paging by timestamp eliminates this problem, and allows you to load additional items in both directions from what you've
already loaded. You can specify `before` or `after` when paging by timestamp, and it will dictate the direction that the
results will be returned.

```ruby
class Item < ActiveRecord::Base
  include Api::Pagination::Timestamp
end

# 5 records, starting at the beginning, ordered by created_at DESC (newest to oldest)
@items = Item.page_by.per(5)
@items = Item.page_by(before: true).per(5)
@items = Item.page_by(before: 'true', per_page: 5)

# 2 records, ordered by created_at ASC (oldest to newest)
@items = Item.page_by(after: true).per(2)

# 5 records, ordered by created_at DESC, where created_at > 2 minutes ago
@items = Item.page_by(before: 2.minutes.ago).per(5)

# 5 records, ordered by created_at ASC, where created_at < 2 minutes ago
@items = Item.page_by(after: 2.minutes.ago).per(5)

# 5 records, ordered by updated_at ASC
@items = Item.page_by(after: true, column: :updated_at).per(5)
```

##### Advanced Usage

There are times, especially within an API where you may want to render a collection of one type of resource, but ordered
a different resource -- by a join table. This can be tricky, but is taken into consideration here. This example is a bit
complex, but shows how it can be accomplished using the `column` option, and `page_value` callback option.

If you provide a `column` option as a symbol, it is assumed to mean a column on the current resource. If you provide a
string (eg. 'table_name.column_name') the WHERE and ORDER clauses will use that table and column after being
sanitized.

```ruby
Item.page_by(column: :updated_at).to_sql
# => SELECT "items".* FROM "items" ORDER BY "items"."updated_at" DESC LIMIT 25
```

```ruby
Item.joins(:likes).page_by(column: 'likes.created_at').per(4).to_sql
# => SELECT "items".* FROM "items"
#    INNER JOIN "likes" ON "likes"."item_id" = "items"."id"
#    ORDER BY likes.created_at DESC LIMIT 4
```

In cases like this, you must also provide a `page_value` callback in the options, otherwise getting the values needed
for the next/prev pages is impossible -- since there's no way to know which attribute to use, and it doesn't exist on
the records we've actually selected. This is the full example of using virtual attributes and a custom select.

```ruby
options = {
  column: 'likes.created_at',
  page_value: ->(item) { item.read_attribute(:like_created_at) },
  per_page: 2
}
items = Item.joins(:likes).select('items.*, likes.created_at AS like_created_at').page_by(options)
items.next_page_value # => the created_at column for the like of the last item in the page.
```


#### TimestampFilterable

This is basically the same as the Timestamp implementation, but will filter out results after they've been queried. We
found it to be considerably faster to filter results after loading them in cases of very complex joins, and queries
dealing with many millions/billions of records.

It works by loading 2 pages worth of records, filtering them down manually, and then using an Enumerable to provide the
results with an enhanced interface. By default, if you ask for 10 items per page, it will do a query to load 20 and then
filter that set down to 10 based on the filter that you've specified -- it's a pessimistic multiplier.

If more records have been filtered than the number asked for, additional queries are performed until the end of the data
has been reached, or enough to fullfil the request have been loaded. This is done using recursion, and so can be highly
expensive if you think many records would be filtered before the desired count is fulfilled. You can modify the
multiplier to load many more pages of records in cases like this.

When using this paginator, a filter is expected, and this can be accomplished in one of three ways. When filtering a
collection of models, it will attempt to call a `filtered?` method on each record unless an alternate `filter` option is
provided. The `filter` option is expected to respond to `.call`, so a proc or instance that implements `.call` can be
used for more complex filtering logic.

Note: This paginator uses a different concept than the Simple and Timestamp paginators, in that it uses an Enumerable
that masquerades to some extent as an ActiveRecord collection, but also includes the common paginator interface. This
means that when you call the `filtered_page_by` method, you are done with the scope chain, and because of this you can
pass a block where additional scopes can be added.

```ruby
class Item < ActiveRecord::Base
  include Api::Pagination::TimestampFilterable
  scope :active, -> { where(active: true) }

  # filter method
  def filtered?
    disabled?
  end

  # filter class
  class Filterer
    def call(record)
      !(record.name =~ /^filtered/)
    end
  end
end

# 5 records, ordered by created_at ASC -- filtered using `Item#filtered?`.
Item.filtered_page_by(after: true, per_page: 5)

# 25 records, ordered by created_at DESC -- filtered using a proc.
Item.filtered_page_by(filter: ->(record) { record.disabled? })

# 25 records, ordered by created_at DESC -- filtered using an instance.
Item.filtered_page_by(filter: Item::Filterer.new)

# 2 records, additional scope, ordered by created_at ASC.
Item.filtered_page_by(after: true, per_page: 2) { |scope| scope.active }
```


## License

Licensed under the [MIT License](http://creativecommons.org/licenses/MIT)

Copyright 2015 [Mode Set](https://github.com/modeset)


## Make Code Not War
![crest](https://secure.gravatar.com/avatar/aa8ea677b07f626479fd280049b0e19f?s=75)
