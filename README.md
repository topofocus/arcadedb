# ArcadeDB — Ruby Interface

Ruby interface to [ArcadeDB](https://arcadedb.com/) via the HTTP-JSON API.
Responses map to a Dry::Struct based ORM: each database type is a model class; graph,
document and time-series queries are expressed in ruby. Includes a Query preprocessor
and a MATCH statement generator.

| | |
|---|---|
| Namespace | `Arcade` |
| Requires | Ruby ≥ 2.7, running ArcadeDB server (tested against 26.10.x) |
| Transport | HTTP/JSON (HTTPX, persistent connection, basic auth) |
| Model layer | Dry::Struct — not ActiveRecord |
| Sibling docs | `RAG_SCHEMA.md` (vector schema), `rails.md`, `CHANGELOG.md` |

## Quick start

```bash
mkdir project && cd project
bundle init && bundle add arcadedb
mkdir model bin
# copy bin/console and arcade.yml from this repo, adapt arcade.yml
```

`arcade.yml` (project root or `config/`):

```yaml
:environment:
  :test:        { dbname: playground, user: root, pass: xxx }
  :development: { dbname: devel,      user: root, pass: xxx }
  :production:  { dbname: production, user: root, pass: xxx }
:admin: { :host: localhost, :port: 2480, :user: root, :pass: xxx }
:logger: stdout
```

Console: `bin/console t|d|p` (test environment also loads the spec model files).
Connection handle: always available as `Arcade::Init.db` after `Arcade::Init.connect :production`.

## Architecture

```
Arcade::Base (Dry::Struct)          model layer
├── Arcade::Vertex   +nodes/edges/traverse/match
├── Arcade::Edge
├── Arcade::Document
├── Arcade::Revision / RevisionRecord    audit trail
└── Arcade::Timeseries                   native time-series types (0.5.4+)

Arcade::Database   db.query / db.execute / db.transmit   (transactions, model allocation)
Arcade::Api        raw HTTP primitives (query, execute, post_text, get_json, ...)
```

Class name maps to database type via `snake_case` (`Demo::User` → `demo_user`).

## Models

```ruby
# model/demo/user.rb
module Demo
  class User < Arcade::Vertex
    attribute :name, Types::Nominal::String

    def grandparents
      db.query("select in('is_family') from #{rid}")&.allocate_model
    end
  end
end
__END__
  CREATE PROPERTY demo_user.name STRING
  CREATE INDEX ON demo_user(name) UNIQUE
```

`Demo::User.create_type` creates the type and runs the `__END__` DDL.
Undeclared properties are schemaless — they arrive in the `values` attribute.

```ruby
Person.insert name: "Hubert", age: 35
Person.update set: { age: 36 }, where: { name: 'Hubert' }
Person.where("age > 40").first.update age: 37
Person.upsert name: 'Hugo'                       # ensure-exists (needs index on field)
Person.delete all: true                          # or where: {...}
```

## Graph: nodes, traverse, match

```ruby
m = Person.insert(name: 'Hubert'); f = Person.insert(name: 'Pauline')
m.assign via: IsMarriedTo, vertex: f, divorced: false

hubert = Person.find(name: 'Hubert')
hubert.nodes(:out, via: IsMarriedTo, where: "age < 30").first   # or hubert.out.first
hubert.edges(via: IsMarriedTo)                                   # edges carry attributes

start_node.traverse :out, via: Connects, depth: 100              # depth-limited walk
```

MATCH generator — also from a vertex instance (handy when `params[:rid]` is given):

```ruby
Arcade::Match.new(type: Person, as: :p).out(IsMarriedTo).node(where: 'age < 30').execute.select_results
Watchlist.match(symbol: 'iBit', as: :w).out(HasUnderlying).node(as: :u)
"#49:0".load_rid.match.out(HasUnderlying).node(as: :u)
```

Query objects nest (hybrid queries without string surgery):

```ruby
Query.new(from: match_object, projection: 'median(note_count)', where: '$depth>=50')
```

## TimeSeries (new in 0.5.4)

Native ArcadeDB time-series types: columnar, compressed, tag-partitioned.
**Not vertices** — no rid, no edges. Membership lives in tags, values in typed fields.

```ruby
# model/ohlcv.rb
class Ohlcv < Arcade::Timeseries
  timestamp :ts, precision: :second          # date-granular series: use :second
  tags   symbol: String, currency: String
  fields open: Float, high: Float, low: Float, close: Float, volume: Integer
end

Ohlcv.create_type

# write — Line Protocol under the hood, batched
Ohlcv.write symbol: 'SAPX:GER', currency: 'EUR', ts: Date.new(2026,10,20),
            open: 290.0, high: 296.0, low: 290.0, close: 295.5, volume: 120
Ohlcv.write_many rows   # array of hashes, one POST per batch

# read — SQL range pushdown
Ohlcv.range from: '2026-01-01', tags: { symbol: 'SAPX:GER' }
Ohlcv.latest tags: { symbol: 'SAPX:GER' }        # => {ts:, close:, ...} or nil

# weekly candles in one query
Ohlcv.bucket '7d', from: Date.new(2024,10,1), tags: { symbol: 'SAPX:GER' },
                   aggregate: { close: :last, high: :max, low: :min, volume: :sum }
```

Accepted `ts` values: `Time`, `Date`, `DateTime`, ISO-String, epoch-seconds — normalised
to UTC and to the declared precision. Timezones: server timestamps are stored absolute;
build Date objects UTC (`Time.utc`) or comparisons drift by the host offset.

## RAG

`require 'arcade/rag_schema'` — vector + full-text schema for retrieval pipelines.
See `RAG_SCHEMA.md` and `examples/rag_example.rb`.

## Transactions & audit

```ruby
db = Arcade::Init.db
db.begin_transaction; ... ; db.commit   # or db.rollback
```

`Arcade::Revision` subclasses keep an append-only `protocol` stack of
`Arcade::RevisionRecord` entries; every `update` appends (old value + action + user).

## Low-level access

```ruby
Arcade::Api.query(db, "select from x")            # parsed :result (array)
Arcade::Api.execute(db) { "update x set ..." }    # write, retry on 'Please retry'
Arcade::Api.get_json("ts/#{db}/latest?type=...")  # raw body (ts endpoints)
Arcade::Api.post_text("ts/#{db}/write?precision=s", lines)  # Line Protocol
db.query("select ...").allocate_model             # hashes -> model objects
```

Query payload hash: `{ query:, language: :sql|:cypher|:gremlin|:neo4j, params:, limit:, serializer: :graph|:record }`.

## Server & version notes (verified ArcadeDB 26.10)

| Observation | Consequence |
|---|---|
| `schema:types` does not list timeseries types | existence probe: `POST /ts/{db}/query` → 400 `unknownTypes`/`does not exist` = absent (`type_exists?` uses this) |
| `CREATE TIMESERIES TYPE` registers asynchronously (~1 s) | `create_type` waits for visibility; a write right after create fails with `unknownTypes` otherwise |
| `DELETE FROM <ts-type> WHERE ...` reports a count but keeps rows (26.10.1) | no window-replace possible; re-writing a timestamp **appends** — deduplicate on read |
| timeseries timestamp precision defaults to NANOSECOND | declare `PRECISION` explicitly; numeric literals are interpreted per precision |
| `bucket` is a reserved word in SQL | aliased in backticks by `bucket()` |
| `IF NOT EXISTS` unsupported on `CREATE TIMESERIES TYPE` | guarded by `type_exists?` |
| Line Protocol needs pre-created types (`tsAutoCreateType` off by default) | `write_many` fails with `unknownTypes` if the type is missing |
| persistent HTTP connections die after ~3 s idle | Primitives renew the handle after 2 s inactivity |

## Testing

```bash
bundle install && bundle exec rspec                  # needs a reachable ArcadeDB server
bundle exec rspec spec/lib/timeseries_spec.rb        # single file; spec/lib/* against arcade.yml :test db
```

Model files for specs live in `spec/model/` (Zeitwerk-loaded). The spec suite is the
authoritative behaviour reference — read `spec/lib/*` before assuming API shape.

## Repository layout

```
lib/arcade.rb              entry point (requires below)
lib/arcade/                base, database, query, match, timeseries, api/, support/
lib/model/                 base classes (vertex, edge, document, revision, timeseries)
lib/models.rb              base-class loader
examples/                  documented use cases
spec/lib, spec/model       rspec suite (authoritative)
bin/console                irb shortcut per environment
```

## Contributing

Bug reports and pull requests are welcome — this project follows the
[Contributor Covenant](http://contributor-covenant.org) code of conduct
([detail](https://github.com/topofocus/arcadedb/blob/master/CODE_OF_CONDUCT.md)).
New behaviour ships with a spec in `spec/lib/` and, if server-quirk-sensitive, a row
in the Server & version notes table.
