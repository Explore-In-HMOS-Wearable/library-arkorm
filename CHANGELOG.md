# Changelog

This project follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-06-26

First stable release. A type-safe ORM for HarmonyOS Next (API 12+).

### Sprint 1 — Metadata Engine
- `MetadataRegistry` (Map-based, no `reflect-metadata`, two-phase prototype staging)
- Decorators: `@Table`, `@Column`, `@PrimaryKey`, `@Unique`, `@Index`
- `ColumnType` enum + SQLite affinity mapping

### Sprint 2 — Database + CRUD
- `@Database` (class = identity marker), `ArkORM.init/getDatabase/close`, multiple databases
- DDL generator (CREATE TABLE/PRIMARY KEY/UNIQUE/INDEX), `EntitySerializer`/`EntityDeserializer`
- `BaseDao` CRUD + batch insert, `OnConflictStrategy`
- `@TypeConverter` + `PropertyConverter` (built-in `DateConverter`)

### Sprint 3 — Fluent Query Builder
- `QueryBuilder` + `Condition`: `eq/ne/gt/gte/lt/lte/between/like/glob/isNull/isNotNull/inList`
- `and/or/beginGroup/endGroup/orderBy/limit/offset`
- Terminals: `findAll/findOne/count/exists/delete/update/findPage` (`PageResult`)

### Sprint 4 — Relations + Transactions
- `@ForeignKey` (CASCADE/SET NULL/RESTRICT) + `PRAGMA foreign_keys = ON`
- `@OneToMany`, `@ManyToOne`, `@EagerLoad`, `RelationLoader` (lazy `load` + `eager`)
- `db.transaction(callback)` commit/rollback
- `targetEntity: () => Entity` thunk for circular-import safety

### Sprint 5 — Migration + Logging
- Automatic migration (new table CREATE, new column ALTER), `SchemaDiff` (PRAGMA table_info)
- Manual `Migration(fromV, toV, fn)` API, `destructiveMigration`
- `Logger` + `ArkORM.setDebugLog`

### Sprint 6 — Tests, Docs, Capstone
- DDL local unit tests + relation/migration integration tests (Hypium)
- `rawQuery` / `rawResultSet` escape hatch
- User → Post → Comment nested relation demo
- README, CHANGELOG

### Known limitations (ArkTS)
- `db.from<T>(T)` and `rawQuery<T>(...)` require an explicit type argument (constructor-type signatures are banned)
- No `@Transaction` method decorator (`Function.apply/call/bind` banned) → use the callback form
- Deserialized entities are plain data objects (not real class instances; no methods)
- Entity inheritance and `@ManyToMany` are out of scope for v1.0
