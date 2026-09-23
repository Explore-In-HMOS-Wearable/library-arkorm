> **Note:** To access all shared projects, get information about environment setup, and view other guides, please visit [Explore-In-HMOS-Wearable Index](https://github.com/Explore-In-HMOS-Wearable/hmos-index).

# ArkORM

A **type-safe**, fully open-source ORM for HarmonyOS Next with a fluent query builder and relation support. Inspired by Android Room, written in pure ArkTS.
You can access the demo application click here 👉 **[ArkORM Demo](https://github.com/Explore-In-HMOS/library-arkorm/tree/main/example)**

## Features

- 🧩 **Pure ArkTS decorators** — `@Table`, `@Column`, `@PrimaryKey` …
- 🔍 **Fluent, type-safe query builder** — chain queries without writing raw SQL
- 🔗 **Relations** — `@OneToMany`, `@ManyToOne`, `@ForeignKey` (CASCADE/SET NULL/RESTRICT), lazy/eager loading
- 🔄 **Automatic + manual migration** — new tables/columns handled automatically; `Migration` API for data moves
- 💳 **Transactions** — callback-based commit/rollback
- 🧪 **TypeConverter** — custom type conversions for `Date`, JSON, etc.
- 🗂️ **Multiple databases**, batch insert, pagination (`PageResult`), debug logging.

## ArkTS Notes (important)

ArkTS strict mode bans some TypeScript features; the ArkORM API is adapted accordingly:

| Constraint | ArkORM approach |
|---|---|
| `new () => T` constructor types are banned | The entity class is passed as a `Function` value; the type argument is given **explicitly**: `db.from<User>(User)` |
| `Object.getPrototypeOf` / `any` banned | `@Database` class is an identity marker; `Object` + union types |
| `Function.apply/call/bind` banned | No `@Transaction` method decorator — use the **callback** `db.transaction(cb)` |
| Circular imports | Relations use a `targetEntity: () => User` **thunk** |
| No `Proxy` | Lazy load is `db.from<T>(T).load(entity, 'rel')` instead of `entity.load()` |

## Installation

```bash
ohpm i @explore-in-hmos/arkorm
# or
ohpm install @explore-in-hmos/arkorm
```

Or reference it locally in `oh-package.json5`:
```json5
{
  "dependencies": {
    "@explore-in-hmos/arkorm": "^1.0.0"
  }
}
```

## Quick Start

### 1. Define an entity
```typescript
import { Table, Column, PrimaryKey, Unique, ColumnType, TypeConverter, DateConverter } from 'arkorm';

@Table({ name: 'users', indexes: [{ columns: ['email'], unique: true, name: 'idx_users_email' }] })
export class User {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  @Column({ type: ColumnType.STR })
  name: string = '';

  @Unique()
  @Column({ type: ColumnType.STR })
  email: string = '';

  @Column({ type: ColumnType.INT, nullable: true })
  age: number | null = null;

  @TypeConverter({ converter: new DateConverter() })
  @Column({ type: ColumnType.INT })
  createdAt: Date = new Date(0);
}
```

### 2. Define a database
```typescript
import { Database } from 'arkorm';

@Database({ entities: [User], name: 'app.db', version: 1 })
export class AppDatabase {}   // not instantiated — just an identity marker
```

### 3. Open and use
```typescript
import { ArkORM, ArkORMDatabase } from 'arkorm';

await ArkORM.init(getContext(this) as common.Context, AppDatabase);
const db: ArkORMDatabase = ArkORM.getDatabase(AppDatabase);

const user = new User();
user.name = 'Demo';
user.email = 'demo@example.com';
const id = await db.from<User>(User).insert(user);   // id is written back: user.id
```

## CRUD

```typescript
const dao = db.from<User>(User);
await dao.insert(user);                  // → rowId (auto PK written back to entity)
await dao.insertAll([u1, u2, u3]);       // batch (sliced by pageSize)
await dao.update(user);                   // by PK
await dao.delete(user);                   // by PK
await dao.insert(user, OnConflictStrategy.IGNORE);  // conflict strategy
```

## Fluent Query Builder

```typescript
const adults = await db.from<User>(User)
  .where('age').gte(18)
  .and('email').isNotNull()
  .orderBy('name')
  .limit(20)
  .findAll();

const one   = await db.from<User>(User).where('email').eq('demo@example.com').findOne();
const count = await db.from<User>(User).where('age').gt(18).count();
const ok    = await db.from<User>(User).where('email').eq('demo@example.com').exists();
const page  = await db.from<User>(User).orderBy('id').findPage(1, 20); // PageResult

// OR grouping
await db.from<User>(User).where('age').lt(20).or('age').gt(40).findAll();
```

Comparisons: `eq, ne, gt, gte, lt, lte, between, like, glob, isNull, isNotNull, inList`.
Terminals: `findAll, findOne, count, exists, delete, update, findPage`.

## Relations

```typescript
@Table({ name: 'posts' })
export class Post {
  @PrimaryKey({ autoGenerate: true }) @Column({ type: ColumnType.INT }) id: number = 0;
  @Column({ type: ColumnType.STR }) title: string = '';

  @ForeignKey({ entity: () => User, parentColumn: 'id', childColumn: 'authorId', onDelete: ForeignKeyAction.CASCADE })
  @Column({ type: ColumnType.INT }) authorId: number = 0;

  @ManyToOne({ targetEntity: () => User, joinColumn: 'authorId' })
  author: User | null = null;
}

// On the User side:
@OneToMany({ targetEntity: () => Post, mappedBy: 'author' })
posts: Post[] = [];
```

```typescript
// Eager (auto-filled during the query)
const u = await db.from<User>(User).eager('posts').where('id').eq(1).findOne();
console.log(u.posts.length);

// Lazy (explicit load)
const post = await db.from<Post>(Post).where('id').eq(1).findOne();
await db.from<Post>(Post).load(post, 'author');   // fills post.author
```

The `@EagerLoad` decorator forces a relation to load on every query. With `@ForeignKey` + `ON DELETE CASCADE`, child rows are deleted automatically when the parent is deleted (`PRAGMA foreign_keys = ON` is enabled automatically).

## Transactions

```typescript
await db.transaction(async (tx) => {
  const uid = await tx.from<User>(User).insert(user);
  await tx.from<Post>(Post).insert({ ...post, authorId: uid });
  // throwing an error triggers an automatic rollback
});
```

## TypeConverter

```typescript
import { PropertyConverter } from 'arkorm';
import { relationalStore } from '@kit.ArkData';

export class JsonConverter extends PropertyConverter {
  convertToEntityProperty(dbValue: relationalStore.ValueType): Object {
    return JSON.parse(dbValue as string) as Object;
  }
  convertToDatabaseValue(value: Object): relationalStore.ValueType {
    return JSON.stringify(value);
  }
}
// usage: @TypeConverter({ converter: new JsonConverter() })
```

A built-in `DateConverter` (Date ↔ epoch-millis) ships out of the box.

## Migration

Bump the version number and ArkORM updates the schema automatically:
- **New table** → `CREATE TABLE`
- **New column** → `ALTER TABLE ADD COLUMN` (the diff is found via `PRAGMA table_info`)

```typescript
import { Migration } from 'arkorm';

const M_1_2 = new Migration(1, 2, async (store) => {
  await store.executeSql('UPDATE users SET name = name || \' \' || surname');
});

@Database({
  entities: [User], name: 'app.db', version: 2,
  migrations: [M_1_2],
  // destructiveMigration: true   // dev: drop + recreate tables
})
export class AppDatabase {}
```

Manual `Migration`s run first, then automatic migration fills in any gaps.

## Raw Query

```typescript
const rows = await db.rawQuery<User>(
  'SELECT * FROM users WHERE age > ?', [18], User);

const rs = await db.rawResultSet('PRAGMA table_info(users)', []);
```

## Multiple Databases & Debug

```typescript
await ArkORM.init(context, AppDatabase);
await ArkORM.init(context, CacheDatabase);
await ArkORM.close(AppDatabase);

ArkORM.setDebugLog(true);   // logs executed SQL/DDL + migration steps to hilog
```

## License

MIT
