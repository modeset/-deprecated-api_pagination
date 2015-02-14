describe Api::Pagination::CommonInterface do
  subject do
    Class.new do
      include Api::Pagination::CommonInterface
      attr_accessor :values
    end.new
  end

  it 'can set pagination options, returning self for chaining' do
    expect(subject.set_pagination_options(foo: 'bar')).to eq(subject)
    expect(subject.values[:_pagination_options]).to eq(foo: 'bar')
  end

  it 'knows it is paginatable' do
    expect(subject.paginatable?).to be_truthy
  end

  it 'understands the basic concept of counts' do
    expect(subject).to respond_to(:total_count)
    expect(subject).to respond_to(:total_pages)
    expect(subject).to respond_to(:total_pages_remaining)
  end

  it 'has a concept of if it is the first page or last page' do
    expect(subject).to respond_to(:first_page?)
    expect(subject).to respond_to(:last_page?)
  end

  it 'has a concept of getting various values for next/prev and other pages' do
    expect(subject).to respond_to(:first_page_value)
    expect(subject).to respond_to(:last_page_value)
    expect(subject).to respond_to(:prev_page_value)
    expect(subject).to respond_to(:next_page_value)
  end

  it 'provides a defined interface for asking for a page param given another page value' do
    expect(subject).to respond_to(:page_param)
  end

end
