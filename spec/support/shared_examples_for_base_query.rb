shared_examples :base_query do

  let(:data_source) { 'some_datasource' }
  let(:query) { described_class.new(data_source) }

  subject { query.to_hash }

  describe '#initialize' do
    its([:dataSource]) { should == data_source }
  end

  describe '#dimensions' do
    before { query.dimensions(:dim1, :dim2) }

    its([:dimensions]) { should be_nil }
    its([:searchDimensions]) { should == ['dim1', 'dim2'] }
  end

  describe '#interval' do
    let(:now) { Time.now }

    before do
      Timecop.freeze(now)
      query.interval(from)
    end

    after { Timecop.return }

    context 'with a numeric from' do
      let(:from) { -86400 }

      its([:intervals]) { should == ["#{(now + from).iso8601}/#{now.iso8601}"] }
    end
  end

  describe '#granularity' do
    before { query.granularity(granularity, time_zone) }

    context 'with a simple granularity' do
      let(:granularity) { :day }
      let(:time_zone) { nil }

      its([:granularity]) { should == granularity.to_s }
    end

    context 'with a period and time zone' do
      let(:granularity) { 'P1D' }
      let(:time_zone) { 'Europe/Berlin' }

      its([:granularity]) { should == { type: :period, period: granularity, timeZone: time_zone } }
    end

    context 'with a duration' do
      let(:granularity) { 5 }
      let(:time_zone) { nil }

      before { query.granularity(granularity) }

      its([:granularity]) { should == { type: :duration, duration: granularity * 1000 } }
    end
  end

end
