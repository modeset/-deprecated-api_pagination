Api::Pagination
===============

[![Build Status](https://img.shields.io/travis/modeset/api_pagination.svg)](https://travis-ci.org/modeset/api_pagination)
[![Code Climate](https://codeclimate.com/repos/54df9005e30ba012930060e4/badges/e466695e9c8859eaafd2/gpa.svg)](https://codeclimate.com/repos/54df9005e30ba012930060e4/feed)
[![Test Coverage](https://codeclimate.com/repos/54df9005e30ba012930060e4/badges/e466695e9c8859eaafd2/coverage.svg)](https://codeclimate.com/repos/54df9005e30ba012930060e4/feed)

Api::Pagination is a collection of pagination scopes that follow a consistent interface so paginated collections can be
referred to throughout your application in consistent terms. This was born from the need for more complex pagination
rules and wanting to provide consistent summaries of the pagination results.

The pagination scopes can be used on ActiveRecord collections, and then the pagination information can be added to the
response headers, which is considered to be best practice for REST APIs and is used by
[GitHub](https://developer.github.com/v3/#pagination).

Links to previous/next pages are available in the `Link` [response header](http://tools.ietf.org/html/rfc5988) as well
as totals in the `X-Total-Count`, `X-Total-Pages` and `X-Total-Pages-Remaining` headers. These can be parsed by client
applications and provided back to the server for subsequent pages.

## Table of Contents

1. [Installation](#installation)
2. [Usage](#usage)


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


## Usage

### Pagination Scopes

#### Simple

This is your basic run of the mill page by number implementation that we're all familiar with. You can mix your own
scopes, ask for a given page, and additionally specify how many results per page. If not specified 25 results will be
returned per page, with a maximum of 100 results even if more are requested.

```ruby
class Item < ActiveRecord::Base
  include Api::Pagination::Simple
end

# 5 records, starting at page 2, ordered by created_at ASC
@items = Item.order(:created_at).page(2).per(5)

# 5 records, starting at page 3
@items = Item.page(page: 3, per_page: 5)
```

Once you've called the page scope, you can begin asking questions about it's results. These are mixed into the scope
chain directly, and so you can ask questions. In these examples, we assume we have 23 records, and have asked for page
3 with 5 per page.

```ruby
@items.paginatable? # => true, if you've used the `page` scope at all.

@items.total_count # => 23 - how many total records there are to page through.
@items.total_pages # => 5 - the total number of pages.
@items.total_pages_remaining # 2 - the number of pages remaining.

@items.first_page? # false - boolean, if it's on the first page or not.
@items.last_page? # false - boolean, if it's on the last page or not.
```

Additionally, you can get the various values to continue loading pages. For instance, you can get the page value for
the first page, last page, etc.

```ruby
@items.first_page_value # => 1 - in the case of the simple paginator, this will always be 1
@items.last_page_value # => 5 - page 5 would only load 3 records
@items.next_page_value # => 4
@items.prev_page_value # => 2
```

#### Timestamp

This is a more robust way to paginate records when content could be added between page requests. For any real time, or
semi-real time project this is the paginator to use.

One of the challenges faced with simple number pagination is that if a new record is added, records already seen can be
duplicated in subsequent page requests. An example of this is listing items from newest to oldest -- if a new item is
created after loading page 1, but before page 2 has been loaded -- page 2 will now include the last item(s) from page 1.

Paging by timestamp eliminates this problem, and any new items that are added between page loads don't cause
duplication. At the same time, you may want to load additional items, which is why you can specify `before` or `after`
when paging by timestamp. If you don't provide any pagination arguments, the first page is assumed (in descending
order), with a default of 25 items, with a maximum of 100.

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

There are times, especially within an API that you may want to get a collection of one object, but order it by a join
table. This can be tricky, but is taken into consideration. This example is a bit complex, but shows how it can be
accomplished using the `column` option, and `page_value` callback option.

If you provide a `column` option as a symbol, it is assumed to mean a column on the current resource.

```ruby
Item.page_by(column: :updated_at).to_sql
# => SELECT "items".* FROM "items" ORDER BY "items"."updated_at" DESC LIMIT 25
```

If you provide a `column` option as a string however, you can specify any column on any table included the query. In our
example, we want to order our items by when their creator was last updated (not the best example, but you get the idea).

```ruby
Item.joins(:creator).page_by(column: 'creators.updated_at').per(2).to_sql
# => SELECT  "items".* FROM "items"
#    INNER JOIN "creators" ON "creators"."id" = "items"."creator_id"
#    ORDER BY creators.updated_at desc LIMIT 2
```

In cases like this, you must also provide a `page_value` callback in the options, otherwise getting the values needed
for the next/prev pages won't work -- since there's no way to know which attribute to use, and it doesn't exist on the
records we've actually selected.

```ruby
page_value_callback = ->(item) { item.creator.updated_at }
@items = Item.joins(:creator).page_by(column: 'creators.updated_at', page_value: page_value_callback).per(2)
@items.next_page_value # => the updated_at column for the creator of the last item in the page.
```

So you can see how the `column` and `page_value` callback options work together in complex ways. In even more complex
scenarios, you can utilize a custom select and psuedo attribute on the records. In the next example, we want to list the
items in the order that they have last been viewed. It's expected that if you're dealing with scenarios like these, you
know what you're doing, and can probably figure it out given a fairly terse example.

```ruby
options = {
  column: 'views.created_at',
  page_value: ->(item) { item.read_attribute(:view_created_at) }
}
Item.all_viewers.select('items.*, view.created_at AS view_created_at').page_by(options)
```


#### TimestampFilterable

This is basically the same as the Timestamp implementation, but will filter out results after they've been loaded. We
found it to be considerably faster to filter results after loading them in cases of very complex joins, and queries
dealing with many millions/billions of records.

It works by loading 2 pages worth of records, filtering them down manually, and then using an Enumerable to provide the
results with an improved interface. By default, if you ask for 10 items per page, it will do a query to load 20 and
filter that set down to 10 based on the filter that you've specified -- it's a pessimistic multiplier. If it has
filtered more records than was asked for an additional query is performed to load more and filters the additional
records until the total number desired is achieved. This is done using recursion, and so can be expensive if you think
many records would be filtered before the desired count is fulfilled. You can modify the multiplier to load many more
records in cases like this.

When using this paginator, a filter is expected, and this can be accomplished in one of three ways. When filtering a
collection of models, it will attempt to call a `filtered?` method on each record unless an alternate `filter` option is
provided. The `filter` option is expected to respond to `.call`, and so a proc or instance that implements `.call` can
be used for more complex filtering logic.

Note: This paginator uses a different concept than the Simple and Timestamp paginators, in that it uses an Enumerable
that masquerades to some extent as an ActiveRecord collection, but also includes the common paginator interface. This
means that when you call the `filtered_page_by` method, you are done with the scope chain, and because of this it allows
passing a block where additional scopes can be added.

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

# 5 records, ordered by created_at DESC -- filtered using `item.filtered?`.
Item.filtered_page_by(before: true, per_page: 5)
Item.filtered_page_by(before: 'true', per_page: 5)

# 25 records, ordered by created_at DESC -- filtered using a proc.
Item.filtered_page_by(filter: ->(record) { record.disabled? })

# 25 records, ordered by created_at DESC -- filtered using a class instance.
Item.filtered_page_by(filter: Item::Filterer.new)

# 2 records, additional scope, ordered by created_at ASC -- filtered using `item.filtered?`.
Item.filtered_page_by(per_page: 2, after: true) { |scope| scope.active }
```


## License

Licensed under the [MIT License](http://creativecommons.org/licenses/MIT)

Copyright 2015 [Mode Set](https://github.com/modeset)


## Make Code Not War
![crest](https://secure.gravatar.com/avatar/aa8ea677b07f626479fd280049b0e19f?s=75)
