require 'active_record_helper'

describe Api::Pagination::TimestampFilterable do
  subject { TimestampFilterableMock }
  let(:time) { Time.zone.parse('Oct 20 00:00:00 GMT 2012') }

  describe 'api' do

    it 'has a default order and limit' do
      expect(subject.filtered_page_by.to_sql).to include('items.created_at DESC')
      expect(subject.filtered_page_by.limit_value).to eq(50)
    end

    it 'limits the amount of records requested to 100' do
      expect(subject.filtered_page_by(per_page: 201).limit_value).to eq(200)
    end

    it 'allows specifying a before option and how many per page' do
      page = subject.filtered_page_by(before: 'true', per_page: 10)
      expect(page.to_sql).to include('items.created_at DESC')
      expect(page.limit_value).to eq(20)

      page = subject.filtered_page_by(before: time, per_page: 12)
      expect(page.to_sql).to include(%{"items"."created_at" < '2012-10-20 00:00:00.000000'})
      expect(page.limit_value).to eq(24)
    end

    it 'allows specifying an after option and how many per page' do
      page = subject.filtered_page_by(after: 'true', per_page: 10)
      expect(page.to_sql).to include('items.created_at ASC')
      expect(page.limit_value).to eq(20)

      page = subject.filtered_page_by(after: time, per_page: 12)
      expect(page.to_sql).to include(%{"items"."created_at" > '2012-10-20 00:00:00.000000'})
      expect(page.limit_value).to eq(24)
    end

    it 'allows lazy loading/filtering the page' do
      item = subject.create!
      page = subject.filtered_page_by(before: true, lazy: true)
      expect(page.instance_variable_get(:@results)).to eq([])
      expect(page.map(&:id)).to eq([item.id])

      page = subject.filtered_page_by(before: true, lazy: true)
      expect(page.to_a).to eq([item])
    end

    it 'allows specifying a different column to sort by' do
      page = subject.filtered_page_by(before: true, column: :updated_at)
      expect(page.to_sql).to include('items.updated_at DESC')

      page = subject.filtered_page_by(after: true, column: :updated_at)
      expect(page.to_sql).to include('items.updated_at ASC')

      page = subject.filtered_page_by(before: time, lazy: true, column: 'other_table.updated_at')
      expect(page.to_sql).to include('other_table.updated_at DESC')
      expect(page.to_sql).to include(%{"other_table"."updated_at" < '2012-10-20 00:00:00.000000'})

      page = subject.filtered_page_by(after: time, lazy: true, column: 'other_table.updated_at')
      expect(page.to_sql).to include('other_table.updated_at ASC')
      expect(page.to_sql).to include(%{"other_table"."updated_at" > '2012-10-20 00:00:00.000000'})
    end

    it 'disregards times that are not parseable' do
      page = subject.filtered_page_by(before: 'wasd')
      expect(page.to_sql).not_to include(%{WHERE})

      page = subject.filtered_page_by(after: 'wasd')
      expect(page.to_sql).not_to include(%{WHERE})
    end

    it 'raises an exception when the timestamp is invalid' do
      expect{ subject.filtered_page_by(before: time.to_f) }.to raise_error(
        Api::Pagination::InvalidTimestampError,
        "Invalid time value #{time.to_f}, expected string matching %Y-%m-%dT%H:%M:%S.%N%z."
      )
    end

    it 'does not allow sql injections' do
      page = subject.filtered_page_by(after: time, lazy: true, column: '1); DELETE	FROM "users"; other_table.created_at')
      expect(page.to_sql).to include(%{"1 DELETEFROMusers other_table"."created_at" > '2012-10-20 00:00:00.000000'})
      expect(page.to_sql).to include(%{1 DELETEFROMusers other_table.created_at ASC})
    end

    describe 'advanced usage' do
      let!(:archer) { User.create!(name: 'archer') }
      let!(:item2) { Item.create!(user: archer, title: 'item-2') }
      let!(:item1) { Item.create!(user: archer, title: 'item-1') }

      let!(:lana) { User.create!(name: 'lana') }
      let!(:item4) { Item.create!(user: lana, title: 'item-4') }
      let!(:item3) { Item.create!(user: lana, title: 'item-3') }

      let!(:like1) { Like.create!(user: archer, item: item3, created_at: time + 2.days) }
      let!(:like2) { Like.create!(user: archer, item: item4, created_at: time + 3.days) }

      it 'allows paging using join and include scenarios' do
        options = { column: 'likes.created_at', per_page: 4, filter: ->(_) {} }

        items = Item.joins(:likes).filtered_page_by(options)
        expect(items.to_a).to eq([item4, item3])
        expect(items.next_page_value).to eq(nil)

        items = Item.joins(:likes).filtered_page_by(options.merge(after: true))
        expect(items.to_a).to eq([item3, item4])
        expect(items.next_page_value).to eq(nil)

        items = Item.includes(:likes).filtered_page_by(options.merge(per_page: 3))
        expect(items.to_a).to eq([item4, item3, item2])
        expect(items.next_page_value).to eq(nil)

        items = Item.includes(:likes).filtered_page_by(options.merge(after: true, per_page: 3))
        expect(items.to_a).to eq([item2, item1, item3])
        expect(items.next_page_value).to eq(nil)
      end

      it 'allows even more complex join functionality using the page value callback' do
        scope = Item.joins(:likes).select('items.*, likes.created_at AS like_created_at')
        value = ->(item) { item.read_attribute('like_created_at') }
        options = { after: true, per_page: 4, column: 'likes.created_at', page_value: value, filter: ->(_) {} }
        items = scope.filtered_page_by(options)
        expect(items.to_a).to eq([item3, item4])
        expect(items.prev_page_value).to eq('2012-10-22 00:00:00.000000')
        expect(items.next_page_value).to eq('2012-10-23 00:00:00.000000')
      end

    end
  end

  describe 'pagination' do
    before do
      5.times { |i| subject.create!(created_at: time - i.days) }
    end

    describe 'page using before' do
      let(:page) { subject.filtered_page_by(before: time, per_page: 2) }

      it 'knows that it is paginatable' do
        expect { subject.paginatable? }.to raise_error
        expect { subject.new.paginatable? }.to raise_error
        expect(page.paginatable?).to be_truthy
      end

      it 'does not know the total count of records' do
        expect(page.total_count).to eq(nil)
      end

      it 'does not know the total number of pages' do
        expect(page.total_pages).to eq(nil)
      end

      it 'does not know how many pages remain' do
        expect(page.total_pages_remaining).to eq(nil)
      end

      it 'knows what the first page is' do
        expect(page.first_page_value).to eq(true)
      end

      it 'knows what the last page is' do
        expect(page.last_page_value).to eq(true)
      end

      it 'knows what the next page is' do
        expect(page.next_page_value).to eq('2012-10-18T00:00:00.000000000+0000')
      end

      it 'knows what the previous page is' do
        expect(page.prev_page_value).to eq('2012-10-19T00:00:00.000000000+0000')
      end

      it 'knows when it is on the first page' do
        page = subject.filtered_page_by(before: true, per_page: 2)
        expect(page.first_page?).to be_truthy

        page = subject.filtered_page_by(before: 'true', per_page: 2)
        expect(page.first_page?).to be_truthy

        page = subject.filtered_page_by(before: time, per_page: 2)
        expect(page.first_page?).to be_falsey

        page = subject.filtered_page_by(before: time - 5.days, per_page: 2)
        expect(page.first_page?).to be_falsey
      end

      it 'never knows when it is on the last page' do
        page = subject.filtered_page_by(before: time - 5.days, per_page: 2)
        expect(page.last_page?).to be_falsey

        page = subject.filtered_page_by(before: time, per_page: 2)
        expect(page.last_page?).to be_falsey
      end

      it 'allows providing a callback for the next/prev pages' do
        page_value_callback = ->(record) { record.created_at.to_s + '!!!!!!' }
        page = subject.filtered_page_by(before: time, page_value: page_value_callback, per_page: 2)
        expect(page.prev_page_value).to eq('2012-10-19 00:00:00 UTC!!!!!!')
        expect(page.next_page_value).to eq('2012-10-18 00:00:00 UTC!!!!!!')
      end

    end

    describe 'page using after' do
      let(:page) { subject.filtered_page_by(after: time - 3.days, per_page: 2) }

      it 'knows that it is paginatable' do
        expect { subject.paginatable? }.to raise_error
        expect { subject.new.paginatable? }.to raise_error
        expect(page.paginatable?).to be_truthy
      end

      it 'does not know the total count of records' do
        expect(page.total_count).to eq(nil)
      end

      it 'does not know the total number of pages' do
        expect(page.total_pages).to eq(nil)
      end

      it 'does not know how many pages remain' do
        expect(page.total_pages_remaining).to eq(nil)
      end

      it 'knows what the first page is' do
        expect(page.first_page_value).to eq(true)
      end

      it 'knows what the last page is' do
        expect(page.last_page_value).to eq(true)
      end

      it 'knows what the next page is' do
        expect(page.next_page_value).to eq('2012-10-19T00:00:00.000000000+0000')
      end

      it 'knows what the previous page is' do
        expect(page.prev_page_value).to eq('2012-10-18T00:00:00.000000000+0000')
      end

      it 'knows when it is on the first page' do
        page = subject.filtered_page_by(after: true, per_page: 2)
        expect(page.first_page?).to be_truthy

        page = subject.filtered_page_by(after: 'true', per_page: 2)
        expect(page.first_page?).to be_truthy

        page = subject.filtered_page_by(after: time, per_page: 2)
        expect(page.first_page?).to be_falsey

        page = subject.filtered_page_by(after: time - 5.days, per_page: 2)
        expect(page.first_page?).to be_falsey
      end

      it 'never knows when it is on the last page' do
        page = subject.filtered_page_by(after: time - 5.days, per_page: 2)
        expect(page.last_page?).to be_falsey

        page = subject.filtered_page_by(after: time, per_page: 2)
        expect(page.last_page?).to be_falsey
      end

      it 'allows providing a callback for the next/prev pages' do
        page_value_callback = ->(record) { record.created_at.to_s + '!!!!!!' }
        page = subject.filtered_page_by(after: time - 5.days, page_value: page_value_callback, per_page: 2)
        expect(page.prev_page_value).to eq('2012-10-16 00:00:00 UTC!!!!!!')
        expect(page.next_page_value).to eq('2012-10-17 00:00:00 UTC!!!!!!')
      end

    end
  end

  describe 'pagination with filtering' do
    let!(:item1) { subject.create!(title: 'unfiltered-item1', created_at: time - 1.day,  active: true) }
    let!(:item2) { subject.create!(title: 'filtered-item2',   created_at: time - 2.days) }
    let!(:item3) { subject.create!(title: 'unfiltered-item3', created_at: time - 3.days, active: true, disabled: true) }
    let!(:item4) { subject.create!(title: 'unfiltered-item4', created_at: time - 4.days, active: true) }
    let!(:item5) { subject.create!(title: 'unfiltered-item5', created_at: time - 5.days) }
    let!(:item6) { subject.create!(title: 'filtered-item6',   created_at: time - 6.days) }
    let!(:item7) { subject.create!(title: 'unfiltered-item7', created_at: time - 7.days) }
    let!(:item8) { subject.create!(title: 'unfiltered-item8', created_at: time - 8.days, active: true, disabled: true) }
    let!(:item9) { subject.create!(title: 'unfiltered-item9', created_at: time - 9.days) }
    let(:params) { { per_page: 2, foo: 'bar' } }

    describe 'on the first page' do

      it 'returns the expected items when no direction is specified' do
        page = subject.filtered_page_by(params)
        expect(page.length).to eq(2)
        expect(page.to_a).to eq([item1, item4])

        expect(Date.parse(page.prev_page_value)).to eq(item1.created_at)
        expect(page.page_param(params, page.next_page_value, 'next')).to eq(
          per_page: 2,
          foo: 'bar',
          before: '2012-10-16T00:00:00.000000000+0000'
        )
      end

      it 'returns the expected items when before is specified' do
        passed_params = params.merge(before: true)
        page = subject.filtered_page_by(passed_params)
        expect(page.length).to eq(2)
        expect(page.to_a).to eq([item1, item4])

        expect(Date.parse(page.prev_page_value)).to eq(item1.created_at)
        expect(page.page_param(params, page.next_page_value, 'next')).to eq(
          per_page: 2,
          foo: 'bar',
          before: '2012-10-16T00:00:00.000000000+0000'
        )
      end

      it 'returns the expected items when after is specified' do
        passed_params = params.merge(after: true)
        page = subject.filtered_page_by(passed_params)
        expect(page.length).to eq(2)
        expect(page.to_a).to eq([item9, item7])

        expect(Date.parse(page.prev_page_value)).to eq(item9.created_at)
        expect(page.page_param(params, page.next_page_value, 'next')).to eq(
          per_page: 2,
          foo: 'bar',
          after: '2012-10-13T00:00:00.000000000+0000'
        )
      end

    end

    describe 'on the last page' do

      it 'returns the expected items when before is specified' do
        passed_params = params.merge(before: time - 7.days)
        page = subject.filtered_page_by(passed_params)
        expect(page.length).to eq(1)
        expect(page.to_a).to eq([item9])

        expect(Date.parse(page.prev_page_value)).to eq(item9.created_at)
        expect(page.page_param(params, page.next_page_value, 'next')).to eq(
          per_page: 2,
          foo: 'bar',
          before: '2012-10-11T00:00:00.000000000+0000'
        )
      end

      it 'returns the expected items when after is specified' do
        passed_params = params.merge(after: time - 2.days)
        page = subject.filtered_page_by(passed_params)
        expect(page.length).to eq(1)
        expect(page.to_a).to eq([item1])

        expect(Date.parse(page.prev_page_value)).to eq(item1.created_at)
        expect(page.page_param(params, page.next_page_value, 'next')).to eq(
          per_page: 2,
          foo: 'bar',
          after: '2012-10-19T00:00:00.000000000+0000'
        )
      end

    end

    describe 'when there are no results' do
      let(:before) { item9.created_at - 1.second }
      let(:after) { item1.created_at + 1.second }

      it 'returns 0 records' do
        page = subject.filtered_page_by(params.merge(before: before))
        expect(page.length).to eq(0)

        page = subject.filtered_page_by(params.merge(after: after))
        expect(page.length).to eq(0)
      end

      it 'knows there is no next page' do
        page = subject.filtered_page_by(params.merge(before: before))
        expect(page.next_page_value).to be_nil

        page = subject.filtered_page_by(params.merge(after: after))
        expect(page.next_page_value).to be_nil
      end

      it 'knows there must be a previous page' do
        page = subject.filtered_page_by(params.merge(before: before))
        expect(page.prev_page_value).to eq(true)

        page = subject.filtered_page_by(params.merge(after: after))
        expect(page.prev_page_value).to eq(true)
      end

    end

    describe 'adding a custom scope in a block' do

      it 'includes that scope in the query' do
        page = subject.filtered_page_by(params.merge(per_page: 10)) { |scope| scope.active }
        expect(page.length).to eq(2)
        expect(page.to_a).to eq([item1, item4])
      end

    end

    describe 'using a proc as the filter method' do

      it 'returns the expected filtered results' do
        page = subject.filtered_page_by(params.merge(per_page: 3, filter: TimestampFilterableMock::FILTER))
        expect(page.length).to eq(3)
        expect(page.to_a).to eq([item1, item2, item4])
      end

    end

    describe 'using a class instance as the filter method' do

      it 'returns the expected filtered results' do
        page = subject.filtered_page_by(params.merge(per_page: 10, filter: TimestampFilterableMock::Filter.new))
        expect(page.length).to eq(7)
        expect(page.to_a).to eq([item1, item3, item4, item5, item7, item8, item9])
      end

    end

    describe 'when all results are filtered on a page' do

      it 'returns the expected page with filtered results (and does not infinitely recurse)' do
        item1.update_attributes(disabled: true)

        page = subject.filtered_page_by(params)
        expect(page.length).to eq(2)
        expect(page.to_a).to eq([item4, item5])
      end

      it 'keeps looking until the end if there are no matches' do
        subject.update_all(disabled: true)

        page = subject.filtered_page_by(per_page: 2)
        expect(page.length).to eq(0)
        expect(page.to_a).to eq([])
      end

    end

    describe 'through multiple pages' do

      it 'returns the expected results' do
        page1 = subject.filtered_page_by(params.merge(after: true))
        expect(page1.first).to eq(item9)
        expect(page1.last).to eq(item7)

        page2 = subject.filtered_page_by(params.merge(after: page1.next_page_value))
        expect(page2.first).to eq(item5)
        expect(page2.last).to eq(item4)

        page1 = subject.filtered_page_by(params.merge(before: page2.prev_page_value))
        expect(page1.first).to eq(item7)
        expect(page1.last).to eq(item9)

        page3 = subject.filtered_page_by(params.merge(after: page2.next_page_value))
        expect(page3.length).to eq(1)
        expect(page3.first).to eq(item1)
        expect(page3.last).to eq(item1)

        page2 = subject.filtered_page_by(params.merge(before: page3.prev_page_value))
        expect(page2.first).to eq(item4)
        expect(page2.last).to eq(item5)
      end

    end
  end
end
