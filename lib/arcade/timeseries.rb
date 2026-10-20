module Arcade
  # Abstraction of ArcadeDB's native TimeSeries types.
  #
  # A TimeSeries type is not a vertex/document: it has no rid and carries no edges.
  # Membership is expressed through tags, values through typed fields.
  #
  #   class Ohlcv < Arcade::Timeseries
  #     timestamp :ts, precision: :second
  #     tags   symbol: String, currency: String
  #     fields open: Float, high: Float, low: Float, close: Float, volume: Integer
  #   end
  #
  #   Ohlcv.create_type
  #   Ohlcv.write symbol: 'SAPX:GER', ts: Date.today, open: 1, high: 2, low: 0.5, close: 1.5, volume: 100
  #   Ohlcv.range from: '2026-01-01', tags: { symbol: 'SAPX:GER' }
  #   Ohlcv.latest tags: { symbol: 'SAPX:GER' }
  #   Ohlcv.bucket '7d', from: '2026-01-01', aggregate: { close: :last, volume: :sum }
  #
  # Conventions:
  # * Writes go through the InfluxDB Line Protocol endpoint (fastest remote path);
  #   reads go through SQL (range pushdown, ts.* functions).
  # * Timestamps are accepted as Time, DateTime, Date, ISO-String or epoch Numeric
  #   and normalised to the declared precision — never pass raw numbers of a
  #   different unit than declared, the engine will not complain but read wrong.
  # * The server's DELETE on timeseries types reports a count but leaves the rows
  #   (ArcadeDB 26.10.1) — there is deliberately no window-replace helper here.
  #   Re-writing a timestamp appends a second sample; deduplicate on read if needed.
  class Timeseries < Base

    TYPES = { String => 'STRING', Float => 'DOUBLE', Integer => 'LONG',
              :bool => 'BOOLEAN', :datetime => 'DATETIME' }.freeze

    # The engine stores EVERY timestamp in milliseconds: on 26.10.1 the declared
    # precision was honoured by no ingestion path (all converted to ms anyway, and
    # RETENTION on a SECOND type deleted everything — fixed in 26.10.2, #9800);
    # from 26.10.2 on, CREATE refuses anything but MILLISECOND. The DDL keyword is
    # therefore always MILLISECOND; the class precision only documents the unit of
    # values passed to .write (normalised to ms before sending, LP precision ms).
    PRECISIONS = { second:      'MILLISECOND',
                   millisecond: 'MILLISECOND',
                   microsecond: 'MILLISECOND',
                   nanosecond:  'MILLISECOND' }.freeze

    LP_PRECISION = 'ms'.freeze

    # ts.<fn>(field, ts) where the engine needs the timestamp, plain SQL otherwise
    AGGREGATES = { last:  ->(f, ts){ "ts.last(#{ f }, #{ ts })" },
                   first: ->(f, ts){ "ts.first(#{ f }, #{ ts })" },
                   avg:   ->(f, _){ "avg(#{ f })" },
                   sum:   ->(f, _){ "sum(#{ f })" },
                   min:   ->(f, _){ "min(#{ f })" },
                   max:   ->(f, _){ "max(#{ f })" },
                   count: ->(f, _){ "count(#{ f })" } }.freeze

    class << self

      # ---- schema declaration -----------------------------------------------------------

      def timestamp name = nil, precision: nil, shards: nil, retention: nil
        if name.nil? && precision.nil?          # getter use:  ts_name via timestamp()
          @ts_name ||= :ts
          @ts_precision ||= :second
          return @ts_name
        end
        @ts_name, @ts_precision = name, (precision || :second)
        @ts_shards, @ts_retention = shards, retention
      end

      def tags spec = nil
        @ts_tags = spec if spec
        @ts_tags ||= {}
      end

      def fields spec = nil
        @ts_fields = spec if spec
        @ts_fields ||= {}
      end

      def ts_name       = timestamp
      def ts_precision  = @ts_precision ||= :second
      def type_name     = database_name

      # ---- type lifecycle ---------------------------------------------------------------

      def create_type
        return true if type_exists?
        tag_cols  = tags.map  { |k, t| "#{ k } #{ sql_type t }" }.join(', ')
        field_cols = fields.map { |k, t| "#{ k } #{ sql_type t }" }.join(', ')
        cmd = "CREATE TIMESERIES TYPE #{ type_name } " \
              "TIMESTAMP #{ ts_name } PRECISION #{ PRECISIONS[ts_precision] } " \
              "TAGS (#{ tag_cols }) FIELDS (#{ field_cols })"
        cmd += " SHARDS #{ @ts_shards }"   if @ts_shards
        cmd += " RETENTION #{ @ts_retention }" if @ts_retention
        result = db.transmit { cmd }
        # the engine registers the type asynchronously — wait until readable
        # (writes immediately after create otherwise fail with unknownTypes)
        10.times { break if type_exists?; sleep 0.2 }
        result
      end

      # NB: schema:types does NOT list timeseries types on 26.10 —
      # probe the ts/query endpoint instead (400 unknownTypes = absent).
      def type_exists?
        Api.post_json "ts/#{ db.database }/query", { type: type_name.to_s }
        true
      rescue Arcade::QueryError
        false
      end

      def drop_type
        db.transmit { "DROP TIMESERIES TYPE #{ type_name }" }
      end

      # ---- writing ----------------------------------------------------------------------

      # one sample:  Ohlcv.write symbol: 'SAP', ts: Date.today, close: 1.5
      def write **sample
        write_many [sample]
      end

      # batch: array of hashes, one per sample (Line Protocol, precision param matches class)
      def write_many samples
        return 0 if samples.empty?
        lines = samples.map { |s| line_for s }
        Api.post_text "ts/#{ db.database }/write?precision=#{ LP_PRECISION }", lines.join("\n")
      end

      # ---- reading ----------------------------------------------------------------------

      # raw samples within [from, to] (both optional), filtered by tag equality
      def range from: nil, to: nil, tags: {}, columns: nil, limit: nil
        projections = columns ? ([ts_name] + Array(columns)).join(', ') : '*'
        conditions  = []
        conditions << "#{ ts_name } >= #{ sql_time from }" if from
        conditions << "#{ ts_name } <= #{ sql_time to }"   if to
        tags.each { |k, v| conditions << "#{ k } = '#{ v }'" }
        sql = "SELECT #{ projections } FROM #{ type_name }"
        sql += " WHERE #{ conditions.join ' AND ' }" unless conditions.empty?
        sql += " ORDER BY #{ ts_name }"
        sql += " LIMIT #{ limit }" if limit
        db.transmit { sql }
      end

      # the most recent sample, via the dedicated latest-endpoint
      # returns a Hash of column => value (nil when the series is empty)
      def latest tags: {}
        query = "ts/#{ db.database }/latest?type=#{ type_name }"
        query += "&tag=#{ tags.first.join ':' }" unless tags.empty?
        answer = Api.get_json query
        return nil if answer[:latest].nil?
        answer[:columns].map.with_index { |col, i| [ col.to_sym, answer[:latest][i] ] }.to_h
      end

      # time-bucketed aggregation, e.g. weekly candles:
      #   Ohlcv.bucket '7d', aggregate: { close: :last, high: :max, low: :min, volume: :sum }
      def bucket interval, from: nil, to: nil, tags: {}, aggregate: {}
        measures = aggregate.map do |field, fn|
          "#{ AGGREGATES.fetch(fn).call(field, ts_name) } as #{ field }_#{ fn }"
        end.join(', ')
        conditions  = []
        conditions << "#{ ts_name } >= #{ sql_time from }" if from
        conditions << "#{ ts_name } <= #{ sql_time to }"   if to
        tags.each { |k, v| conditions << "#{ k } = '#{ v }'" }
        sql = "SELECT ts.timeBucket('#{ interval }', #{ ts_name }) as `bucket`"
        sql += ", #{ measures }" unless measures.empty?
        sql += " FROM #{ type_name }"
        sql += " WHERE #{ conditions.join ' AND ' }" unless conditions.empty?
        sql += " GROUP BY `bucket` ORDER BY `bucket`"
        db.transmit { sql }
      end

      private

      # ---- normalisation ------------------------------------------------------------------

      def sql_type type
        TYPES.fetch(type) { type.to_s.upcase }
      end

      # sample hash -> InfluxDB line, epoch normalised to the declared precision
      def line_for sample
        stamp = to_epoch sample[ts_name] || sample[ts_name.to_s]
        raise ArgumentError, "#{ type_name }: missing timestamp '#{ ts_name }'" if stamp.nil?
        tag_part   = tags.keys.map   { |t| "#{ t }=#{ escape_tag sample[t] }" }.join(',')
        field_part = fields.keys.map  { |f| "#{ f }=#{ sample[f] }" }.join(',')
        "#{ type_name },#{ tag_part } #{ field_part } #{ stamp }"
      end

      def to_epoch value
        seconds = case value
                  when Time then value.to_i
                  when Numeric then value.to_i          # already epoch seconds
                  when Date then Time.utc(value.year, value.month, value.day).to_i
                  when String then Time.parse(value).to_i
                  else nil end
        return nil if seconds.nil?
        seconds * 1_000                      # engine stores milliseconds — always
      end

      def sql_time value
        t = case value
            when Time then value
            when Date then Time.utc(value.year, value.month, value.day)
            when String then Time.parse(value, in: 'UTC')
            when Numeric then Time.at(value)
            else raise ArgumentError, "unsupported time: #{ value.inspect }" end
        "'#{ t.utc.strftime('%Y-%m-%d %H:%M:%S') }'"
      end

      def escape_tag value
        value.to_s.gsub(/([,= ])/) { '\\' + $1 }
      end

    end
  end
end
