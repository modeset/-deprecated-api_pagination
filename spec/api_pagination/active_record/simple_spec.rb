require 'active_record_helper'

describe Api::Pagination::Simple do
  subject { SimpleMock }

  describe 'api' do

    it 'allows paginating using params' do
      expect(subject.page.offset_value).to eq(0)
      expect(subject.page.limit_value).to eq(25)

      expect(subject.page(page: '-1').offset_value).to eq(0)
      expect(subject.page(page: 'x').offset_value).to eq(0)
      expect(subject.page(page: 2).offset_value).to eq(25)

      scope = subject.page(page: 3, per_page: 5)
      expect(scope.offset_value).to eq(10)
      expect(scope.limit_value).to eq(5)
    end

    it 'allows paginating using ints' do
      expect(subject.page.offset_value).to eq(0)
      expect(subject.page.limit_value).to eq(25)

      expect(subject.page(0).offset_value).to eq(0)
      expect(subject.page('x').offset_value).to eq(0)
      expect(subject.page(2).offset_value).to eq(25)

      scope = subject.page(3).per(5)
      expect(scope.offset_value).to eq(10)
      expect(scope.limit_value).to eq(5)
    end

  end

  describe 'scope' do
    let(:scope) { subject.page(2).per(2) }
    before do
      5.times { Item.create! }
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
      expect(scope.next_page_value).to eq(3)
    end

    it 'knows what the previous page is' do
      expect(scope.prev_page_value).to eq(1)
    end

    it 'knows what the first page is' do
      expect(scope.first_page_value).to eq(1)
    end

    it 'knows what the last page is' do
      expect(scope.last_page_value).to eq(3)
    end

    it 'knows when it is on the first page' do
      allow(scope).to receive(:current_page).and_return(1)
      expect(scope.first_page?).to be_truthy

      allow(scope).to receive(:current_page).and_return(2)
      expect(scope.first_page?).to be_falsey
    end

    it 'knows when it is on the last page' do
      allow(scope).to receive(:current_page).and_return(3)
      expect(scope.last_page?).to be_truthy

      allow(scope).to receive(:current_page).and_return(2)
      expect(scope.last_page?).to be_falsey
    end

  end

  describe 'paginating' do
    let(:time) { Time.parse('Oct 20 00:00:00 GMT 2012') }
    before do
      5.times { |i| Item.create!(created_at: time - i.days) }
    end

    it 'returns the expected results' do
      page1 = subject.order('created_at DESC').page.per(2)
      expect(page1.first.created_at.to_s).to eq('2012-10-20 00:00:00 UTC')
      expect(page1.last.created_at.to_s).to eq('2012-10-19 00:00:00 UTC')
      expect(page1.total_pages_remaining).to eq(2)

      page2 = subject.page(page1.next_page_value).per(2)
      expect(page2.first.created_at.to_s).to eq('2012-10-18 00:00:00 UTC')
      expect(page2.last.created_at.to_s).to eq('2012-10-17 00:00:00 UTC')
      expect(page2.total_pages_remaining).to eq(1)

      page1 = subject.page(page1.prev_page_value).per(2)
      expect(page1.first.created_at.to_s).to eq('2012-10-20 00:00:00 UTC')
      expect(page1.last.created_at.to_s).to eq('2012-10-19 00:00:00 UTC')
      expect(page1.total_pages_remaining).to eq(2)

      page3 = subject.page(page2.next_page_value).per(2)
      expect(page3.first.created_at.to_s).to eq('2012-10-16 00:00:00 UTC')
      expect(page3.length).to eq(1)
      expect(page3.total_pages_remaining).to eq(0)
      expect(page3.next_page_value).to be_nil
    end

  end

  describe 'generating params' do
    let(:time) { Time.parse('Oct 20 00:00:00 GMT 2012') }
    let(:params) { { foo: 'bar' } }
    before do
      5.times { |i| Item.create!(created_at: time - i.days) }
    end

    it 'adds paginator params to existing params' do
      page = subject.order('created_at DESC').page.per(2)
      expect(page.page_param(params, page.first_page_value, '_')).to eq(page: 1, foo: 'bar')
      expect(page.page_param(params, page.last_page_value, '_')).to eq(page: 3, foo: 'bar')
      expect(page.page_param(params, page.prev_page_value, '_')).to eq(page: nil, foo: 'bar')
      expect(page.page_param(params, page.next_page_value, '_')).to eq(page: 2, foo: 'bar')
    end

  end
end
