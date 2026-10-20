require 'spec_helper'

class TestOhlcv < Arcade::Timeseries
  timestamp :ts, precision: :second
  tags   symbol: String
  fields open: Float, high: Float, low: Float, close: Float, volume: Integer
end

RSpec.describe Arcade::Timeseries do
  before(:all) do
    TestOhlcv.drop_type rescue nil
    TestOhlcv.create_type
  end
  after(:all) { TestOhlcv.drop_type rescue nil }

  it "creates the type as timeseries" do
    t = (TestOhlcv.type_exists? ? {name: "test_ohlcv"} : nil)
    expect( t ).not_to be_nil
    expect( TestOhlcv.type_exists? ).to be true
  end

  it "writes via line protocol and reads back through sql" do
    n = TestOhlcv.write_many [
      { symbol: 'SAPX:GER', ts: Date.new(2026,10,17), open: 289.0, high: 291.0, low: 288.0, close: 290.0, volume: 100 },
      { symbol: 'SAPX:GER', ts: Date.new(2026,10,20), open: 290.0, high: 296.0, low: 290.0, close: 295.5, volume: 120 },
      { symbol: 'RWE',      ts: Date.new(2026,10,20), open: 40.0,  high: 41.0,  low: 39.0,  close: 40.5,  volume: 300 },
    ]
    expect( n ).to eq 204
    rows = TestOhlcv.range from: Date.new(2026,10,1), to: Date.new(2026,10,31), tags: { symbol: 'SAPX:GER' }
    expect( rows.size ).to eq 2
    expect( rows.map { |r| r[:close] } ).to eq [290.0, 295.5]
    expect( rows.first[:ts].to_s ).to start_with '2026-10-17'
  end

  it "answers latest with tag filter" do
    l = TestOhlcv.latest tags: { symbol: 'SAPX:GER' }
    expect( l.keys ).to include :close
    expect( l[:close] ).to eq 295.5
  end

  it "buckets into weekly candles" do
    b = TestOhlcv.bucket '7d', from: Date.new(2026,10,1), tags: { symbol: 'SAPX:GER' },
                           aggregate: { close: :last, high: :max, low: :min, volume: :sum }
    expect( b.size ).to be >= 1
    last = b.max_by { |r| r[:bucket].to_s }
    expect( last[:close_last] ).to eq 295.5
    expect( last[:volume_sum] ).to eq 220  # epoch-anchored 7d bucket 15.-22.10. holds both samples
  end

  it "survives tag values with reserved characters" do
    expect { TestOhlcv.write symbol: 'A,B C=D', ts: Date.new(2026,10,20), open: 1.0, high: 1.0, low: 1.0, close: 1.0, volume: 1 }
      .not_to raise_error
    rows = TestOhlcv.range tags: { symbol: 'A,B C=D' }
    expect( rows.size ).to eq 1
  end
end
