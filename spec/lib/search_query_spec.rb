require 'support/shared_examples_for_base_query'

describe Druid::SearchQuery do

  it_behaves_like :base_query

  let(:data_source) { 'some_datasource' }
  let(:query) { Druid::SearchQuery.new(data_source) }

  subject { query.to_hash }

  describe '#initialize' do
    its([:queryType]) { should == :search }
  end

  describe '#contains' do
    before { query.contains(value) }

    context 'with a single value' do
      let(:value) { 'foo' }

      its([:query]) { should == { type: :insensitive_contains, value: value } }
    end

    context 'with multiple values' do
      let(:value) { ['foo', 'bar'] }

      its([:query]) { should == { type: :fragment, values: value } }
    end
  end

  describe '#sort' do
    let(:type) { 'strlen' }

    before { query.sort(type) }

    its([:sort]) { should == type }
  end

end
