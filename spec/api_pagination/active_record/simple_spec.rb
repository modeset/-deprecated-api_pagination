require 'active_record_helper'

describe Api::Pagination::Simple do
  subject { SimpleMock }
  let(:time) { Time.zone.parse('Oct 20 00:00:00 GMT 2012') }

  describe 'api' do

    it 'has a default offset and limit' do
      expect(subject.page.offset_value).to eq(0)
      expect(subject.page.limit_value).to eq(25)
    end

    it 'allows specifying a page and how many per page' do
      expect(subject.page(0).offset_value).to eq(0)
      expect(subject.page(1).offset_value).to eq(0)
      expect(subject.page('x').offset_value).to eq(0)
      expect(subject.page(2).offset_value).to eq(25)

      scope = subject.page(3).per(5)
      expect(scope.offset_value).to eq(10)
      expect(scope.limit_value).to eq(5)

      scope = subject.page(6).per(10)
      expect(scope.offset_value).to eq(50)
      expect(scope.limit_value).to eq(10)
    end

    it 'allows using an options hash' do
      expect(subject.page(page: 0).offset_value).to eq(0)
      expect(subject.page(page: 1).offset_value).to eq(0)
      expect(subject.page(page: '-1').offset_value).to eq(0)
      expect(subject.page(page: 'x').offset_value).to eq(0)
      expect(subject.page(page: 2).offset_value).to eq(25)

      scope = subject.page(page: 3, per_page: 5)
      expect(scope.offset_value).to eq(10)
      expect(scope.limit_value).to eq(5)

      scope = subject.page(page: 6, per_page: 10)
      expect(scope.offset_value).to eq(50)
      expect(scope.limit_value).to eq(10)
    end

    describe 'advanced usage' do
      let!(:archer) { User.create!(name: 'archer') }
      let!(:item1) { Item.create!(user: archer, title: 'item-1') }
      let!(:item2) { Item.create!(user: archer, title: 'item-2') }

      let!(:lana) { User.create!(name: 'lana') }
      let!(:item3) { Item.create!(user: lana, title: 'item-3') }
      let!(:item4) { Item.create!(user: lana, title: 'item-4') }

      it 'allows paging using join and include scenarious' do
        Like.create!(user: archer, item: item3, created_at: time - 1.day)
        Like.create!(user: archer, item: item4, created_at: time - 2.days)

        items = Item.joins(:likes).page(per_page: 4).order('likes.created_at DESC')
        expect(items).to eq([item3, item4])
        expect(items.next_page_value).to eq(nil)

        items = Item.includes(:likes).page(per_page: 4).order('likes.created_at DESC')
        expect(items).to eq([item3, item4, item1, item2])
        expect(items.next_page_value).to eq(nil)

        items = Item.joins(:likes).page(per_page: 1).order('likes.created_at ASC')
        expect(items).to eq([item4])
        expect(items.next_page_value).to eq(2)
      end

    end
  end

  describe 'scope' do
    let(:scope) { subject.page(2).per(2) }
    before do
      5.times { subject.create! }
    end

    it 'knows that it is paginatable' do
      expect { subject.paginatable? }.to raise_error
      expect { subject.new.paginatable? }.to raise_error
      expect(subject.page.paginatable?).to be_truthy
    end

    it 'knows the total count of records' do
      expect(scope.total_count).to eq(5)
    end

    it 'knows the total number pages' do
      expect(scope.total_pages).to eq(3)
    end

    it 'knows how many pages remain' do
      expect(scope.total_pages_remaining).to eq(1)
    end

    it 'knows what the first page is' do
      expect(scope.first_page_value).to eq(1)
    end

    it 'knows what the last page is' do
      expect(scope.last_page_value).to eq(3)
    end

    it 'knows what the next page is' do
      expect(scope.next_page_value).to eq(3)
    end

    it 'knows what the previous page is' do
      expect(scope.prev_page_value).to eq(1)
    end

    it 'knows when it is the first page' do
      allow(scope).to receive(:current_page).and_return(1)
      expect(scope.first_page?).to be_truthy

      allow(scope).to receive(:current_page).and_return(2)
      expect(scope.first_page?).to be_falsey
    end

    it 'knows when it is the last page' do
      allow(scope).to receive(:current_page).and_return(3)
      expect(scope.last_page?).to be_truthy

      allow(scope).to receive(:current_page).and_return(2)
      expect(scope.last_page?).to be_falsey
    end

  end

  describe 'pagination' do
    before do
      5.times { |i| subject.create!(created_at: time - i.days) }
    end

    it 'returns the expected results when navigating through pages' do
      page1 = subject.order('created_at DESC').page.per(2)
      expect(page1.first.created_at).to eq(time)
      expect(page1.last.created_at).to eq(time - 1.day)
      expect(page1.total_pages_remaining).to eq(2)

      page2 = subject.page(page1.next_page_value).per(2)
      expect(page2.first.created_at).to eq(time - 2.days)
      expect(page2.last.created_at).to eq(time - 3.days)
      expect(page2.total_pages_remaining).to eq(1)

      page1 = subject.page(page1.prev_page_value).per(2)
      expect(page1.first.created_at).to eq(time)
      expect(page1.last.created_at).to eq(time - 1.day)
      expect(page1.total_pages_remaining).to eq(2)

      page3 = subject.page(page2.next_page_value).per(2)
      expect(page3.length).to eq(1)
      expect(page3.first.created_at).to eq(time - 4.days)
      expect(page3.last.created_at).to eq(time - 4.days)
      expect(page3.total_pages_remaining).to eq(0)
      expect(page3.next_page_value).to be_nil
    end

    describe 'params' do
      let(:params) { { foo: 'bar' } }

      it 'can be built for additional pages including additional params' do
        page = subject.order('created_at DESC').page.per(2)
        expect(page.page_param(params, page.first_page_value, 'first')).to eq(page: 1, foo: 'bar')
        expect(page.page_param(params, page.last_page_value, 'last')).to eq(page: 3, foo: 'bar')
        expect(page.page_param(params, page.prev_page_value, 'prev')).to eq(page: nil, foo: 'bar')
        expect(page.page_param(params, page.next_page_value, 'next')).to eq(page: 2, foo: 'bar')
      end

    end
  end
end
