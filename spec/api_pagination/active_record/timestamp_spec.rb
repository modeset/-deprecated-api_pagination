require 'active_record_helper'

describe Api::Pagination::Timestamp do
  subject { TimestampMock }
  let(:time) { Time.zone.parse('Oct 20 00:00:00 GMT 2012') }

  describe 'api' do

    it 'allows paginating' do
      order_sql = 'BY "items"."created_at" DESC LIMIT 10'
      before_sql = '"items"."created_at" < \'2012-10-20 00:00:00.000000\''
      after_sql = '"items"."created_at" > \'2012-10-20 00:00:00.000000\''
      expect(subject.page_by(per_page: 10).to_sql).to include(order_sql)
      expect(subject.page_by(before: time).to_sql).to include(before_sql)
      expect(subject.page_by(after: time).to_sql).to include(after_sql)

      scope = subject.page_by.per(5)
      expect(scope.limit_value).to eq(5)
    end

    it 'raises an exception when the timestamp is invalid' do
      expect{ subject.page_by(before: time.to_f) }.to raise_error(
        Api::Pagination::InvalidTimestampError,
        "Invalid time value #{time.to_f}, expected string matching %Y-%m-%dT%H:%M:%S.%N%z."
      )
    end

  end

  describe 'scope (using before)' do
    let(:scope) { subject.page_by(before: time).per(2) }
    before do
      5.times { |i| subject.create!(created_at: time - i.days) }
    end

    it 'knows when it is paginatable' do
      expect(scope.paginatable?).to be_truthy
    end

    it 'knows the total count of records' do
      expect(scope.total_count).to eq(5)
    end

    it 'knows the total pages based on how many per page' do
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
      scope = subject.page_by.per(2)
      expect(scope.first_page?).to be_truthy
      expect(Date.parse(scope.prev_page_value)).to eq subject.order(created_at: :desc).first.created_at

      scope = subject.page_by(before: time).per(2)
      expect(scope.first_page?).to be_falsey
      expect(scope.prev_page_value).to_not be_nil
    end

    it 'knows when it is on the last page' do
      scope = subject.page_by(before: time - 5.days).per(2)
      expect(scope.last_page?).to be_truthy
      expect(scope.next_page_value).to be_nil

      scope = subject.page_by.per(2)
      expect(scope.last_page?).to be_falsey
      expect(scope.next_page_value).to_not be_nil
    end

    it 'allows specifying a different tables column' do
      scope = subject.page_by(before: time, column: 'other_table.created_at')
      expect(scope.to_sql).to include("other_table.created_at < '2012-10-20 00:00:00.000000'")
      expect(scope.to_sql).to include('other_table.created_at desc')
    end

    it 'allows providing a callback for the next/prev pages' do
      proc = ->(record) { record.created_at.to_s + '!!!!!!' }
      scope = subject.page_by(before: time - 2.days, page_value: proc).per(1)
      expect(scope.next_page_value).to eq('2012-10-17 00:00:00 UTC!!!!!!')
      expect(scope.prev_page_value).to eq('2012-10-17 00:00:00 UTC!!!!!!')
    end

  end

  describe 'scope (using after)' do
    let(:scope) { subject.page_by(after: time - 3.days).per(2) }
    before do
      5.times { |i| subject.create!(created_at: time - i.days) }
    end

    it 'knows when it is paginatable' do
      expect(scope.paginatable?).to be_truthy
    end

    it 'knows the total count of records' do
      expect(scope.total_count).to eq(5)
    end

    it 'knows the total pages based on how many per page' do
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
      scope = subject.page_by(after: time - 5.days).per(2)
      expect(scope.first_page?).to be_truthy

      scope = subject.page_by(after: time - 1.day).per(2)
      expect(scope.first_page?).to be_falsey
    end

    it 'knows when it is on the last page' do
      scope = subject.page_by(after: time).per(2)
      expect(scope.last_page?).to be_truthy

      scope = subject.page_by(after: time - 3.days).per(2)
      expect(scope.last_page?).to be_falsey
    end

    it 'allows specifying a different tables column' do
      scope = subject.page_by(after: time, column: 'other_table.created_at')
      expect(scope.to_sql).to include("other_table.created_at > '2012-10-20 00:00:00.000000'")
      expect(scope.to_sql).to include('other_table.created_at asc')
    end

    it 'allows providing a callback for the next/prev pages' do
      proc = ->(record) { record.created_at.to_s + '!!!!!!' }
      scope = subject.page_by(after: time - 2.days, page_value: proc).per(1)
      expect(scope.next_page_value).to eq('2012-10-19 00:00:00 UTC!!!!!!')
      expect(scope.prev_page_value).to eq('2012-10-19 00:00:00 UTC!!!!!!')
    end

  end

  describe 'paginating' do
    before do
      5.times { |i| subject.create!(created_at: time - i.days, updated_at: time - i.days) }
    end

    context 'by created_at' do

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

      describe 'generating params' do
        let(:params) { { foo: 'bar' } }

        it 'adds paginator params to existing params' do
          page = subject.page_by.per(2)
          prev_page_param = '2012-10-20T00:00:00.000000000+0000'
          next_page_param = '2012-10-19T00:00:00.000000000+0000'
          expect(page.page_param(params, page.first_page_value, 'first')).to eq(before: true, foo: 'bar')
          expect(page.page_param(params, page.last_page_value, 'last')).to eq(after: true, foo: 'bar')
          expect(page.page_param(params, page.prev_page_value, 'prev')).to eq(after: prev_page_param, foo: 'bar')
          expect(page.page_param(params, page.next_page_value, 'next')).to eq(before: next_page_param, foo: 'bar')
        end

      end
    end

    context 'by updated_at' do

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

      describe 'generating params' do
        let(:params) { { foo: 'bar' } }

        it 'adds paginator params to existing params' do
          page = subject.page_by(column: :updated_at).per(2)
          prev_page_param = '2012-10-20T00:00:00.000000000+0000'
          next_page_param = '2012-10-19T00:00:00.000000000+0000'
          expect(page.page_param(params, page.first_page_value, 'first')).to eq(before: true, foo: 'bar')
          expect(page.page_param(params, page.last_page_value, 'last')).to eq(after: true, foo: 'bar')
          expect(page.page_param(params, page.prev_page_value, 'prev')).to eq(after: prev_page_param, foo: 'bar')
          expect(page.page_param(params, page.next_page_value, 'next')).to eq(before: next_page_param, foo: 'bar')
        end

      end
    end

    context 'in reverse order (using after)' do

      it 'returns the expected results' do
        page1 = subject.page_by(after: time - 6.days).per(2)

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

      describe 'generating params' do
        let(:params) { { foo: 'bar' } }

        it 'adds paginator params to existing params' do
          page = subject.page_by(after: time - 6.days).per(2)
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
