Api::Pagination
===============

[![Build Status](https://img.shields.io/travis/modeset/api_pagination.svg)](https://travis-ci.org/modeset/api_pagination)
[![Code Climate](https://codeclimate.com/repos/54df9005e30ba012930060e4/badges/e466695e9c8859eaafd2/gpa.svg)](https://codeclimate.com/repos/54df9005e30ba012930060e4/feed)
[![Test Coverage](https://codeclimate.com/repos/54df9005e30ba012930060e4/badges/e466695e9c8859eaafd2/coverage.svg)](https://codeclimate.com/repos/54df9005e30ba012930060e4/feed)

Api::Pagination is a collection of pagination scopes that follow a consistent interface so paginated items can be
referred to throughout your application in consistent terms. This was born from needing more complex pagination rules,
and there not being an adequate solution that covered all cases we needed.

## Table of Contents

1. [Installation](#installation)
2. [Usage](#usage)


## Installation

Add it to your Gemfile.

```ruby
gem 'api_pagination'
```

## Usage

### Simple Paginator

Simple paginator is your basic run of the mill page by number implementation. You can mix your own scopes, ask for a
given page, and additionally specify how many results per page. If not specified 25 results will be returned per page,
with a maximum of 100 results even if more are requested.

```ruby
class MyModel < ActiveRecord::Base
  include Api::Pagination::Simple
end

MyModel.order('created_at DESC').page(2).per(5) # 5 records, starting at page 2
```

### Timestamp Paginator

The Timestamp paginator is a more robust way to paginate records where content is being consistently added between page
requests. This provides the benefit of not getting duplicate records in subsequent page requests.

```ruby
class MyModel < ActiveRecord::Base
  include Api::Pagination::Timestamp
end

MyModel.page_by(before: true).per(5) # 5 records, ordered by created_at DESC
MyModel.page_by(before: 2.minutes.ago).per(5) # 5 records, ordered by created_at DESC, where created_at > 2 minutes ago
MyModel.page_by(after: true).per(5) # 5 records, ordered by created_at ASC
MyModel.page_by(after: 2.minutes.ago).per(5) # 5 records, ordered by created_at ASC, where created_at < 2 minutes ago
MyModel.page_by(after: true, column: :updated_at).per(5) # 5 records, ordered by updated_at ASC
```

- TODO: document more complex usages with the `page_value` callback, and how to accomplish pagination with join tables.

### TimestampFilterable Paginator

The TimestampFilterable paginator will load 2 pages of records and filter them down based on filtering logic, and will
load additional pages if too many records have been filtered it. It primarily behaves as the Timestamp paginator, but
expects a filter to be provided, or calls a `filtered?` method on each of the active record objects as it generates
the page.

This is a slightly different concept than the Simple and Timestamp paginators, in that it uses an enumerable instance
that masquerades as an active record collection, but includes the common paginator interface.

```ruby
class MyModel < ActiveRecord::Base
  include Api::Pagination::TimestampFilterable
  def filtered?
    id > 3
  end
end

MyModel.filtered_page_by(before: true).per(5) # 5 records, ordered by created_at DESC
```

- TODO: document more complex usages with the `filter:` option using a proc or a class that responds to `call`.
- TODO: document how the filtered api is the end of the scope chain, but accepts a block to add additional scoping to.
- TODO: explain the limitations of using the enumerator, and the complications that can arise if not understood.
- TODO: explain advanced usage, like using join tables for order/filtering.

## License

Licensed under the [MIT License](http://creativecommons.org/licenses/MIT)

Copyright 2015 [Mode Set](https://github.com/modeset)


## Make Code Not War
![crest](https://secure.gravatar.com/avatar/aa8ea677b07f626479fd280049b0e19f?s=75)
