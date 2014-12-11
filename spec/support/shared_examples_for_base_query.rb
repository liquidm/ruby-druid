shared_examples :base_query do

  let(:now) { Time.now }
  let(:data_source) { 'some_datasource' }
  let(:query) { described_class.new(data_source) }

  before { Timecop.freeze(now) }
  after { Timecop.return }

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
    let(:from) { -86400 }

    it 'calls #intervals' do
      expect(query).to receive(:intervals).with([[from, Time.now]])
      query.interval(from)
    end
  end

  describe '#intervals' do
    before { query.intervals(intervals) }

    context 'with numeric values' do
      let(:intervals) { [[-360, -240], [-120, 0]] }

      its([:intervals]) { should == [
        "#{(now + intervals[0][0]).iso8601}/#{(now + intervals[0][1]).iso8601}",
        "#{(now + intervals[1][0]).iso8601}/#{(now + intervals[1][1]).iso8601}",
      ]}
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
