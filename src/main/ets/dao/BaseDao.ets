import { relationalStore } from '@kit.ArkData';
import { metadataRegistry } from '../core/MetadataRegistry';
import { ColumnMeta, TableMeta } from '../types/Metadata';
import { OnConflictStrategy, toConflictResolution } from '../types/OnConflictStrategy';
import { EntitySerializer } from '../serializer/EntitySerializer';
import { Condition, QueryBuilder } from '../query/QueryBuilder';
import { PageResult } from '../query/PageResult';
import { RelationLoader } from '../relation/RelationLoader';

/**
 * Base CRUD + query entry point for an entity type.
 * Obtained via `ArkORMDatabase.from<T>(Entity)`. The entity handle is a
 * `Function` (the class itself); the type argument is supplied explicitly at
 * the call site (ArkTS constructor-type constraint).
 */
export class BaseDao<T> {
  private store: relationalStore.RdbStore;
  private meta: TableMeta;
  private pageSize: number = 500;

  constructor(entityClass: Function, store: relationalStore.RdbStore) {
    this.store = store;
    this.meta = metadataRegistry.get(entityClass);
  }

  /** Returns a fresh QueryBuilder (no conditions). */
  query(): QueryBuilder<T> {
    return new QueryBuilder<T>(this.meta, this.store);
  }

  /** `db.from<User>(User).where('age').gte(18)...` */
  where(field: string): Condition<T> {
    return this.query().where(field);
  }

  orderBy(field: string, desc: boolean = false): QueryBuilder<T> {
    return this.query().orderBy(field, desc);
  }

  /** Eager-loads a relation (delegates to QueryBuilder). */
  eager(relationName: string): QueryBuilder<T> {
    return this.query().eager(relationName);
  }

  limit(count: number): QueryBuilder<T> {
    return this.query().limit(count);
  }

  /** All records (no conditions). */
  findAll(): Promise<T[]> {
    return this.query().findAll();
  }

  count(): Promise<number> {
    return this.query().count();
  }

  findPage(page: number, size: number): Promise<PageResult<T>> {
    return this.query().findPage(page, size);
  }

  /**
   * Explicitly (lazily) loads an entity's relation and writes it back onto the entity.
   * `await db.from<User>(User).load(user, 'posts')`.
   */
  async load(entity: T, relationName: string): Promise<void> {
    await RelationLoader.load(this.store, this.meta, entity as Object, relationName);
  }

  /** Inserts a single entity; if the PK is auto-generated, the produced rowId is written back to the entity. */
  async insert(entity: T, conflict: OnConflictStrategy = OnConflictStrategy.NONE): Promise<number> {
    const bucket: relationalStore.ValuesBucket =
      EntitySerializer.serialize(entity, this.meta, this.autoPkPropertyKeys());
    const rowId: number = await this.store.insert(this.meta.tableName, bucket, toConflictResolution(conflict));
    this.writeBackAutoPk(entity, rowId);
    return rowId;
  }

  /** Batch insert; sliced by pageSize to manage the 2MB/memory limit. */
  async insertAll(entities: T[]): Promise<number> {
    const skip: string[] = this.autoPkPropertyKeys();
    let total: number = 0;
    for (let i = 0; i < entities.length; i += this.pageSize) {
      const slice: T[] = entities.slice(i, i + this.pageSize);
      const buckets: relationalStore.ValuesBucket[] =
        slice.map((e: T): relationalStore.ValuesBucket => EntitySerializer.serialize(e, this.meta, skip));
      const inserted: number = await this.store.batchInsert(this.meta.tableName, buckets);
      if (inserted > 0) {
        total += inserted;
      }
    }
    return total;
  }

  /** Updates by PK; PK columns go to WHERE, the remaining columns become SET. */
  async update(entity: T, conflict: OnConflictStrategy = OnConflictStrategy.NONE): Promise<number> {
    const bucket: relationalStore.ValuesBucket =
      EntitySerializer.serialize(entity, this.meta, this.pkPropertyKeys());
    return this.store.update(bucket, this.pkPredicates(entity), toConflictResolution(conflict));
  }

  async updateAll(entities: T[]): Promise<number> {
    let total: number = 0;
    for (const entity of entities) {
      total += await this.update(entity);
    }
    return total;
  }

  /** Deletes by PK. */
  async delete(entity: T): Promise<number> {
    return this.store.delete(this.pkPredicates(entity));
  }

  async deleteAll(entities: T[]): Promise<number> {
    let total: number = 0;
    for (const entity of entities) {
      total += await this.delete(entity);
    }
    return total;
  }

  // ---- helpers ----

  private autoPkPropertyKeys(): string[] {
    const keys: string[] = [];
    for (const col of this.meta.getColumns()) {
      if (col.isPrimaryKey && col.autoGenerate) {
        keys.push(col.propertyKey);
      }
    }
    return keys;
  }

  private pkPropertyKeys(): string[] {
    return this.meta.getPrimaryKeys().map((c: ColumnMeta): string => c.propertyKey);
  }

  private pkPredicates(entity: T): relationalStore.RdbPredicates {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(this.meta.tableName);
    const source: Record<string, Object | null> = entity as object as Record<string, Object | null>;
    const pks: ColumnMeta[] = this.meta.getPrimaryKeys();
    if (pks.length === 0) {
      throw new Error(`ArkORM: table '${this.meta.tableName}' has no PK; update/delete by entity is not possible.`);
    }
    for (const pk of pks) {
      const value: Object | null = source[pk.propertyKey];
      predicates.equalTo(pk.columnName, value as relationalStore.ValueType);
    }
    return predicates;
  }

  private writeBackAutoPk(entity: T, rowId: number): void {
    if (rowId < 0) {
      return;
    }
    const target: Record<string, Object | null> = entity as object as Record<string, Object | null>;
    for (const col of this.meta.getColumns()) {
      if (col.isPrimaryKey && col.autoGenerate) {
        target[col.propertyKey] = rowId;
        return;
      }
    }
  }
}
