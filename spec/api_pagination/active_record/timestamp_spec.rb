require 'active_record_helper'

describe Api::Pagination::Timestamp do
  subject { TimestampMock }
  let(:time) { Time.zone.parse('Oct 20 00:00:00 GMT 2012') }

  describe 'api' do

    it 'has a default order and limit' do
      expect(subject.page_by.to_sql).to include('items.created_at DESC')
      expect(subject.page_by.limit_value).to eq(25)
    end

    it 'limits the amount of records requested to 100' do
      expect(subject.page_by.per(200).limit_value).to eq(100)
    end

    it 'allows specifying a before option and how many per page' do
      page = subject.page_by(before: true).per(10)
      expect(page.to_sql).to include('items.created_at DESC')
      expect(page.limit_value).to eq(10)

      page = subject.page_by(before: 'true', per_page: 20)
      expect(page.to_sql).to include('items.created_at DESC')
      expect(page.limit_value).to eq(20)

      page = subject.page_by(before: time).per(12)
      expect(page.to_sql).to include(%{"items"."created_at" < '2012-10-20 00:00:00.000000'})
      expect(page.limit_value).to eq(12)
    end

    it 'allows specifying an after option and how many per page' do
      page = subject.page_by(after: true).per(10)
      expect(page.to_sql).to include('items.created_at ASC')
      expect(page.limit_value).to eq(10)

      page = subject.page_by(after: 'true', per_page: 20)
      expect(page.to_sql).to include('items.created_at ASC')
      expect(page.limit_value).to eq(20)

      page = subject.page_by(after: time).per(12)
      expect(page.to_sql).to include(%{"items"."created_at" > '2012-10-20 00:00:00.000000'})
      expect(page.limit_value).to eq(12)
    end

    it 'allows specifying a different column to sort by' do
      page = subject.page_by(before: true, column: :updated_at)
      expect(page.to_sql).to include('items.updated_at DESC')

      page = subject.page_by(after: true, column: :updated_at)
      expect(page.to_sql).to include('items.updated_at ASC')

      page = subject.page_by(before: time, column: 'other_table.updated_at')
      expect(page.to_sql).to include('other_table.updated_at DESC')
      expect(page.to_sql).to include(%{"other_table"."updated_at" < '2012-10-20 00:00:00.000000'})

      page = subject.page_by(after: time, column: 'other_table.updated_at')
      expect(page.to_sql).to include('other_table.updated_at ASC')
      expect(page.to_sql).to include(%{"other_table"."updated_at" > '2012-10-20 00:00:00.000000'})
    end

    it 'disregards times that are not parseable' do
      page = subject.page_by(before: 'wasd')
      expect(page.to_sql).not_to include(%{WHERE})

      page = subject.page_by(after: 'wasd')
      expect(page.to_sql).not_to include(%{WHERE})
    end

    it 'raises an exception when the timestamp is invalid' do
      expect{ subject.page_by(before: time.to_f) }.to raise_error(
          Api::Pagination::InvalidTimestampError,
          "Invalid time value #{time.to_f}, expected string matching %Y-%m-%dT%H:%M:%S.%N%z."
        )
    end

    it 'does not allow sql injections' do
      page = subject.page_by(after: time, column: '1); DELETE	FROM "users"; other_table.created_at')
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
        items = Item.joins(:likes).page_by(column: 'likes.created_at').per(4)
        expect(items).to eq([item4, item3])
        expect(items.next_page_value).to eq(nil)

        items = Item.joins(:likes).page_by(after: true, column: 'likes.created_at').per(4)
        expect(items).to eq([item3, item4])
        expect(items.next_page_value).to eq(nil)

        items = Item.includes(:likes).page_by(column: 'likes.created_at').per(3)
        expect(items).to eq([item4, item3, item2])
        expect(items.next_page_value).to eq(nil)

        items = Item.includes(:likes).page_by(after: true, column: 'likes.created_at').per(3)
        expect(items).to eq([item2, item1, item3])
        expect(items.next_page_value).to eq(nil)
      end

      it 'allows even more complex join functionality using the page value callback' do
        scope = Item.joins(:likes).select('items.*, likes.created_at AS like_created_at')
        value = ->(item) { item.read_attribute('like_created_at') }
        items = scope.page_by(after: true, column: 'likes.created_at', page_value: value).per(4)
        expect(items).to eq([item3, item4])
        expect(items.prev_page_value).to eq('2012-10-22 00:00:00.000000')
        expect(items.next_page_value).to eq('2012-10-23 00:00:00.000000')
      end

    end
  end

  describe 'pagination' do
    before do
      5.times { |i| subject.create!(created_at: time - i.days, updated_at: time - i.days) }
    end

    describe 'scope using before' do
      let(:scope) { subject.page_by(before: time).per(2) }

      it 'knows that it is paginatable' do
        expect { subject.paginatable? }.to raise_error
        expect { subject.new.paginatable? }.to raise_error
        expect(scope.paginatable?).to be_truthy
      end

      it 'knows the total count of records' do
        expect(scope.total_count).to eq(5)
      end

      it 'knows the total number of pages' do
        expect(scope.total_pages).to eq(3)
      end

      it 'knows how many pages remain' do
        expect(scope.total_pages_remaining).to eq(1)
      end

      it 'knows what the first page is' do
        expect(scope.first_page_value).to eq(true)
      end

      it 'knows what the last page is' do
        expect(scope.last_page_value).to eq(true)
      end

      it 'knows what the next page is' do
        expect(scope.next_page_value).to eq('2012-10-18T00:00:00.000000000+0000')
      end

      it 'knows what the previous page is' do
        expect(scope.prev_page_value).to eq('2012-10-19T00:00:00.000000000+0000')
      end

      it 'knows when it is on the first page' do
        page = subject.page_by(before: true).per(2)
        expect(page.first_page?).to be_truthy

        page = subject.page_by(before: time + 2.days).per(2)
        expect(page.first_page?).to be_truthy

        page = subject.page_by(before: time).per(2)
        expect(page.first_page?).to be_falsey
      end

      it 'knows when it is on the last page' do
        page = subject.page_by(before: time - 2.days).per(2)
        expect(page.last_page?).to be_truthy

        page = subject.page_by(before: time).per(2)
        expect(page.last_page?).to be_falsey
      end

      it 'allows providing a callback for the next/prev pages' do
        page = subject.page_by(page_value: ->(record) { record.created_at.to_s + '!!!!!!' }).per(2)
        expect(page.next_page_value).to eq('2012-10-19 00:00:00 UTC!!!!!!')
        expect(page.prev_page_value).to eq('2012-10-20 00:00:00 UTC!!!!!!')
      end

    end

    describe 'scope using after' do
      let(:scope) { subject.page_by(after: time - 3.days).per(2) }

      it 'knows that it is paginatable' do
        expect { subject.paginatable? }.to raise_error
        expect { subject.new.paginatable? }.to raise_error
        expect(scope.paginatable?).to be_truthy
      end

      it 'knows the total count of records' do
        expect(scope.total_count).to eq(5)
      end

      it 'knows the total number of pages' do
        expect(scope.total_pages).to eq(3)
      end

      it 'knows how many pages remain' do
        expect(scope.total_pages_remaining).to eq(1)
      end

      it 'knows what the next page is' do
        expect(scope.next_page_value).to eq('2012-10-19T00:00:00.000000000+0000')
      end

      it 'knows what the previous page is' do
        expect(scope.prev_page_value).to eq('2012-10-18T00:00:00.000000000+0000')
      end

      it 'knows when it is on the first page' do
        page = subject.page_by(after: true).per(2)
        expect(page.first_page?).to be_truthy

        page = subject.page_by(after: time - 5.days).per(2)
        expect(page.first_page?).to be_truthy

        page = subject.page_by(after: time - 3.days).per(2)
        expect(page.first_page?).to be_falsey
      end

      it 'knows when it is on the last page' do
        page = subject.page_by(after: time - 1.days).per(2)
        expect(page.last_page?).to be_truthy

        page = subject.page_by(after: time - 3.days).per(2)
        expect(page.last_page?).to be_falsey
      end

      it 'allows providing a callback for the next/prev pages' do
        proc = ->(record) { record.created_at.to_s + '!!!!!!' }
        scope = subject.page_by(after: time - 2.days, page_value: proc).per(1)
        expect(scope.next_page_value).to eq('2012-10-19 00:00:00 UTC!!!!!!')
        expect(scope.prev_page_value).to eq('2012-10-19 00:00:00 UTC!!!!!!')
      end

    end

    describe 'navigating through pages by created_at' do

      it 'returns the expected results' do
        page1 = subject.page_by.per(2)
        expect(page1.first.created_at.to_s).to eq('2012-10-20 00:00:00 UTC')
        expect(page1.last.created_at.to_s).to eq('2012-10-19 00:00:00 UTC')
        expect(page1.total_pages_remaining).to eq(2)

        page2 = subject.page_by(before: page1.next_page_value).per(2)
        expect(page2.first.created_at.to_s).to eq('2012-10-18 00:00:00 UTC')
        expect(page2.last.created_at.to_s).to eq('2012-10-17 00:00:00 UTC')
        expect(page2.total_pages_remaining).to eq(1)

        page3 = subject.page_by(before: page2.next_page_value).per(2)
        expect(page3.first.created_at.to_s).to eq('2012-10-16 00:00:00 UTC')
        expect(page3.length).to eq(1)
        expect(page3.total_pages_remaining).to eq(0)
        expect(Date.parse(page3.next_page_value)).to eq subject.order(created_at: :desc).last.created_at
      end

      describe 'params' do
        let(:params) { { foo: 'bar' } }

        it 'can be built for additional pages including additional params' do
          page = subject.page_by(before: true).per(2)
          prev_page_param = '2012-10-20T00:00:00.000000000+0000'
          next_page_param = '2012-10-19T00:00:00.000000000+0000'
          expect(page.page_param(params, page.first_page_value, 'first')).to eq(before: true, foo: 'bar')
          expect(page.page_param(params, page.last_page_value, 'last')).to eq(after: true, foo: 'bar')
          expect(page.page_param(params, page.prev_page_value, 'prev')).to eq(after: prev_page_param, foo: 'bar')
          expect(page.page_param(params, page.next_page_value, 'next')).to eq(before: next_page_param, foo: 'bar')
        end

      end
    end

    describe 'navigating through pages by updated_at' do

      it 'returns the expected results' do
        page1 = subject.page_by(column: :updated_at).per(2)
        expect(page1.first.updated_at.to_s).to eq('2012-10-20 00:00:00 UTC')
        expect(page1.last.updated_at.to_s).to eq('2012-10-19 00:00:00 UTC')
        expect(page1.total_pages_remaining).to eq(2)

        page2 = subject.page_by(before: page1.next_page_value, column: :updated_at).per(2)
        expect(page2.first.updated_at.to_s).to eq('2012-10-18 00:00:00 UTC')
        expect(page2.last.updated_at.to_s).to eq('2012-10-17 00:00:00 UTC')
        expect(page2.total_pages_remaining).to eq(1)

        page3 = subject.page_by(before: page2.next_page_value, column: :updated_at).per(2)
        expect(page3.first.updated_at.to_s).to eq('2012-10-16 00:00:00 UTC')
        expect(page3.length).to eq(1)
        expect(page3.total_pages_remaining).to eq(0)
        expect(Date.parse(page3.next_page_value)).to eq subject.order(updated_at: :desc).last.updated_at
      end

      describe 'params' do
        let(:params) { { foo: 'bar' } }

        it 'can be built for additional pages including additional params' do
          page = subject.page_by(before: true, column: :updated_at).per(2)
          prev_page_param = '2012-10-20T00:00:00.000000000+0000'
          next_page_param = '2012-10-19T00:00:00.000000000+0000'
          expect(page.page_param(params, page.first_page_value, 'first')).to eq(before: true, foo: 'bar')
          expect(page.page_param(params, page.last_page_value, 'last')).to eq(after: true, foo: 'bar')
          expect(page.page_param(params, page.prev_page_value, 'prev')).to eq(after: prev_page_param, foo: 'bar')
          expect(page.page_param(params, page.next_page_value, 'next')).to eq(before: next_page_param, foo: 'bar')
        end

      end
    end

    describe 'navigating through pages in reverse order' do

      it 'returns the expected results' do
        page1 = subject.page_by(after: time - 5.days).per(2)

        expect(page1.first.created_at.to_s).to eq('2012-10-16 00:00:00 UTC')
        expect(page1.last.created_at.to_s).to eq('2012-10-17 00:00:00 UTC')
        expect(page1.total_pages_remaining).to eq(2)

        page2 = subject.page_by(after: page1.next_page_value).per(2)
        expect(page2.first.created_at.to_s).to eq('2012-10-18 00:00:00 UTC')
        expect(page2.last.created_at.to_s).to eq('2012-10-19 00:00:00 UTC')
        expect(page2.total_pages_remaining).to eq(1)

        page3 = subject.page_by(after: page2.next_page_value).per(2)
        expect(page3.first.created_at.to_s).to eq('2012-10-20 00:00:00 UTC')
        expect(page3.length).to eq(1)
        expect(page3.total_pages_remaining).to eq(0)
        expect(Date.parse(page3.next_page_value)).to eq subject.order(created_at: :asc).last.created_at
      end

      describe 'params' do
        let(:params) { { foo: 'bar' } }

        it 'can be built for additional pages including additional params' do
          page = subject.page_by(after: true).per(2)
          prev_page_param = '2012-10-16T00:00:00.000000000+0000'
          next_page_param = '2012-10-17T00:00:00.000000000+0000'
          expect(page.page_param(params, page.first_page_value, 'first')).to eq(after: true, foo: 'bar')
          expect(page.page_param(params, page.last_page_value, 'last')).to eq(before: true, foo: 'bar')
          expect(page.page_param(params, page.prev_page_value, 'prev')).to eq(before: prev_page_param, foo: 'bar')
          expect(page.page_param(params, page.next_page_value, 'next')).to eq(after: next_page_param, foo: 'bar')
        end

      end
    end
  end
end
