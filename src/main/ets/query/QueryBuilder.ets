import { relationalStore } from '@kit.ArkData';
import { ColumnMeta, TableMeta } from '../types/Metadata';
import { EntityDeserializer } from '../serializer/EntityDeserializer';
import { RelationLoader } from '../relation/RelationLoader';
import { PageResult } from './PageResult';

/**
 * Fluent, type-safe query builder built on the HarmonyOS `RdbPredicates` engine.
 * Single-use (each `from()`/`query()` call produces a fresh builder). Field names
 * are given as property keys and mapped to DB column names internally
 * (`@Column({ name })` is supported).
 *
 * ```
 * const users = await db.from<User>(User)
 *   .where('age').gte(18)
 *   .and('email').isNotNull()
 *   .orderBy('name')
 *   .limit(20)
 *   .findAll();
 * ```
 *
 * Note (ArkTS): `Condition` is defined in the same file — otherwise the two
 * classes would import each other and form a cycle.
 */
export class QueryBuilder<T> {
  private store: relationalStore.RdbStore;
  private meta: TableMeta;
  private predicates: relationalStore.RdbPredicates;
  private eagerRelations: string[] = [];

  constructor(meta: TableMeta, store: relationalStore.RdbStore) {
    this.meta = meta;
    this.store = store;
    this.predicates = new relationalStore.RdbPredicates(meta.tableName);
  }

  /** Eager-loads a relation for this query. */
  eager(relationName: string): QueryBuilder<T> {
    if (!this.eagerRelations.includes(relationName)) {
      this.eagerRelations.push(relationName);
    }
    return this;
  }

  /** Loads eager relations (from metadata + .eager()) for the result rows. */
  private async populateEager(rows: T[]): Promise<void> {
    const names: string[] = [];
    for (const rel of this.meta.relations.values()) {
      if (rel.eager) {
        names.push(rel.propertyKey);
      }
    }
    for (const n of this.eagerRelations) {
      if (!names.includes(n)) {
        names.push(n);
      }
    }
    if (names.length === 0) {
      return;
    }
    for (const row of rows) {
      for (const n of names) {
        await RelationLoader.load(this.store, this.meta, row as Object, n);
      }
    }
  }

  /** Maps a property key to its DB column name. */
  private col(field: string): string {
    const c: ColumnMeta | undefined = this.meta.getColumn(field);
    return c !== undefined ? c.columnName : field;
  }

  /** Internal — used by Condition. */
  predicate(): relationalStore.RdbPredicates {
    return this.predicates;
  }

  where(field: string): Condition<T> {
    return new Condition<T>(this, this.predicates, this.col(field));
  }

  /** ANDs with the previous condition (RdbPredicates defaults to AND anyway). */
  and(field: string): Condition<T> {
    this.predicates.and();
    return new Condition<T>(this, this.predicates, this.col(field));
  }

  /** ORs with the previous condition. */
  or(field: string): Condition<T> {
    this.predicates.or();
    return new Condition<T>(this, this.predicates, this.col(field));
  }

  beginGroup(): QueryBuilder<T> {
    this.predicates.beginWrap();
    return this;
  }

  endGroup(): QueryBuilder<T> {
    this.predicates.endWrap();
    return this;
  }

  orderBy(field: string, desc: boolean = false): QueryBuilder<T> {
    if (desc) {
      this.predicates.orderByDesc(this.col(field));
    } else {
      this.predicates.orderByAsc(this.col(field));
    }
    return this;
  }

  limit(count: number): QueryBuilder<T> {
    this.predicates.limitAs(count);
    return this;
  }

  offset(rowOffset: number): QueryBuilder<T> {
    this.predicates.offsetAs(rowOffset);
    return this;
  }

  async findAll(): Promise<T[]> {
    const rs: relationalStore.ResultSet = await this.store.query(this.predicates);
    const rows: T[] = EntityDeserializer.deserializeAll<T>(rs, this.meta);
    rs.close();
    await this.populateEager(rows);
    return rows;
  }

  async findOne(): Promise<T | null> {
    this.predicates.limitAs(1);
    const rs: relationalStore.ResultSet = await this.store.query(this.predicates);
    const rows: T[] = EntityDeserializer.deserializeAll<T>(rs, this.meta);
    rs.close();
    if (rows.length === 0) {
      return null;
    }
    await this.populateEager(rows);
    return rows[0];
  }

  async count(): Promise<number> {
    const rs: relationalStore.ResultSet = await this.store.query(this.predicates);
    const total: number = rs.rowCount;
    rs.close();
    return total;
  }

  async exists(): Promise<boolean> {
    const total: number = await this.count();
    return total > 0;
  }

  async delete(): Promise<number> {
    return this.store.delete(this.predicates);
  }

  /**
   * Updates records matching the WHERE conditions. The keys of `values` are DB
   * column names (use the column name when it differs from the property key).
   */
  async update(values: relationalStore.ValuesBucket): Promise<number> {
    return this.store.update(values, this.predicates);
  }

  /** Pagination: count total first, then fetch data with limit/offset. */
  async findPage(page: number, size: number): Promise<PageResult<T>> {
    const rsCount: relationalStore.ResultSet = await this.store.query(this.predicates);
    const total: number = rsCount.rowCount;
    rsCount.close();

    const offset: number = (page - 1) * size;
    this.predicates.limitAs(size).offsetAs(offset);
    const rs: relationalStore.ResultSet = await this.store.query(this.predicates);
    const data: T[] = EntityDeserializer.deserializeAll<T>(rs, this.meta);
    rs.close();
    await this.populateEager(data);

    const totalPages: number = size > 0 ? Math.ceil(total / size) : 0;
    return new PageResult<T>(data, total, page, totalPages);
  }
}

/**
 * Comparison context for a field. Each comparison method appends the predicate
 * and returns the QueryBuilder to continue chaining.
 */
export class Condition<T> {
  private builder: QueryBuilder<T>;
  private predicates: relationalStore.RdbPredicates;
  private column: string;

  constructor(builder: QueryBuilder<T>, predicates: relationalStore.RdbPredicates, column: string) {
    this.builder = builder;
    this.predicates = predicates;
    this.column = column;
  }

  eq(value: relationalStore.ValueType): QueryBuilder<T> {
    this.predicates.equalTo(this.column, value);
    return this.builder;
  }

  ne(value: relationalStore.ValueType): QueryBuilder<T> {
    this.predicates.notEqualTo(this.column, value);
    return this.builder;
  }

  gt(value: relationalStore.ValueType): QueryBuilder<T> {
    this.predicates.greaterThan(this.column, value);
    return this.builder;
  }

  gte(value: relationalStore.ValueType): QueryBuilder<T> {
    this.predicates.greaterThanOrEqualTo(this.column, value);
    return this.builder;
  }

  lt(value: relationalStore.ValueType): QueryBuilder<T> {
    this.predicates.lessThan(this.column, value);
    return this.builder;
  }

  lte(value: relationalStore.ValueType): QueryBuilder<T> {
    this.predicates.lessThanOrEqualTo(this.column, value);
    return this.builder;
  }

  between(low: relationalStore.ValueType, high: relationalStore.ValueType): QueryBuilder<T> {
    this.predicates.between(this.column, low, high);
    return this.builder;
  }

  like(pattern: string): QueryBuilder<T> {
    this.predicates.like(this.column, pattern);
    return this.builder;
  }

  glob(pattern: string): QueryBuilder<T> {
    this.predicates.glob(this.column, pattern);
    return this.builder;
  }

  isNull(): QueryBuilder<T> {
    this.predicates.isNull(this.column);
    return this.builder;
  }

  isNotNull(): QueryBuilder<T> {
    this.predicates.isNotNull(this.column);
    return this.builder;
  }

  /** IN — named `inList` because `in` is an operator keyword in ArkTS. */
  inList(values: relationalStore.ValueType[]): QueryBuilder<T> {
    this.predicates.in(this.column, values);
    return this.builder;
  }
}
