import { relationalStore } from '@kit.ArkData';
import { BaseDao } from '../dao/BaseDao';
import { metadataRegistry } from './MetadataRegistry';
import { TableMeta } from '../types/Metadata';
import { EntityDeserializer } from '../serializer/EntityDeserializer';

/**
 * Access handle to an open database (library-owned; not subclassed by users).
 * Obtained via `ArkORM.getDatabase(AppDatabase)`.
 *
 * Note: Because ArkTS bans constructor-type signatures and restricted stdlib
 * APIs such as `Object.getPrototypeOf`, the user's `@Database` class is only an
 * IDENTITY marker (never instantiated); the store is held on this handle.
 *
 * ```
 * await ArkORM.init(context, AppDatabase);
 * const db = ArkORM.getDatabase(AppDatabase);
 * await db.from<User>(User).insert(user);
 * ```
 */
export class ArkORMDatabase {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Access to the open `RdbStore` (for raw query / transaction). */
  get rdbStore(): relationalStore.RdbStore {
    return this.store;
  }

  /**
   * Returns a CRUD DAO for an entity. The type argument must be given explicitly:
   * `db.from<User>(User)`.
   */
  from<T>(entity: Function): BaseDao<T> {
    return new BaseDao<T>(entity, this.store);
  }

  /**
   * Callback-based transaction. All operations inside `action` run in a single
   * transaction; if an error is thrown it rolls back automatically.
   *
   * Note (ArkTS): The `@Transaction` method decorator is unsupported — method
   * wrapping is impossible because `Function.apply/call/bind` are banned in
   * ArkTS strict mode. This callback form is the recommended way.
   *
   * ```
   * await db.transaction(async (tx) => {
   *   const uid = await tx.from<User>(User).insert(user);
   *   await tx.from<Post>(Post).insert(post);
   * });
   * ```
   */
  async transaction<R>(action: (tx: ArkORMDatabase) => Promise<R>): Promise<R> {
    this.store.beginTransaction();
    try {
      const result: R = await action(this);
      this.store.commit();
      return result;
    } catch (err) {
      this.store.rollBack();
      throw err as Error;
    }
  }

  /**
   * Raw SQL → entity array (escape hatch). The type argument must be given explicitly:
   * `db.rawQuery<User>('SELECT * FROM users WHERE age > ?', [18], User)`.
   */
  async rawQuery<T>(sql: string, bindArgs: relationalStore.ValueType[], entity: Function): Promise<T[]> {
    const meta: TableMeta = metadataRegistry.get(entity);
    const rs: relationalStore.ResultSet = await this.store.querySql(sql, bindArgs);
    const rows: T[] = EntityDeserializer.deserializeAll<T>(rs, meta);
    rs.close();
    return rows;
  }

  /** Raw SQL → raw ResultSet (caller is responsible for closing). */
  async rawResultSet(sql: string, bindArgs: relationalStore.ValueType[]): Promise<relationalStore.ResultSet> {
    return this.store.querySql(sql, bindArgs);
  }
}

