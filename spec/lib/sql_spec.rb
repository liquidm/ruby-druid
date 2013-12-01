require 'druid/sql'
require 'parslet/rig/rspec'


describe Druid::SQL do
  context '#parser' do
    let(:parser) { Druid::SQL.new }

    context "aggregations" do
      it { should parse('select 1 as constant from source') }
      it { should parse('select count(*) as count from source') }
      it { should parse('select sum(metric) as sum from source') }
      it { should parse('select sum(metric) + 1 as sum from source') }
      it { should parse('select sum(rt)/count(*) as avg from source') }
      it { should parse('select (sum(rt)/count(*)) + 1 as avg from source') }
    end

    context "interval" do
      it { should parse('select count(*) as count from source where timestamp between 1 and 2') }
      it { should parse('select count(*) as count from source where timestamp between "2013-01-01" and "2013-12-31"') }
    end

    context "filter" do
      it { should parse('select count(*) as count from source where dim1 = "foo" and dim2 ~ "bar"') }
      it { should parse('select count(*) as count from source where dim1 = "foo" or dim2 ~ "bar"') }
      it { should parse('select count(*) as count from source where (dim1 = "foo" and dim2 ~ "bar") or dim3 = "baz"') }
      it { should parse('select count(*) as count from source where !(dim1 != "foo" and dim2 ~ "bar") or dim3 = "baz"') }
    end
  end
end
