import { ColumnMeta, IndexMeta, PendingPropertyIndex, RelationMeta, TableIndexOption, TableMeta } from '../types/Metadata';

/**
 * Heart of ArkORM: a registry holding entity metadata at runtime in pure
 * ArkTS, without `reflect-metadata`.
 *
 * Two-stage (staging) design — required by decorator execution order:
 *  1. Property decorators (`@Column`, `@PrimaryKey`, `@Unique`, `@Index`)
 *     run FIRST; `target` = prototype. Metadata is accumulated into the
 *     `drafts` map keyed by prototype.
 *  2. The class decorator (`@Table`) runs LAST; `target` = constructor.
 *     `finalizeTable` locates the draft via the `(ctor).prototype` bridge,
 *     resolves it, and moves it into the final `tables` map keyed by constructor.
 *
 * Reading `target.constructor` is avoided: in ArkTS strict mode the
 * `constructor` typing on `Object` is unreliable. Instead the `Function.prototype`
 * reference identity is used (the same object the property decorator sees).
 */
export class MetadataRegistry {
  private tables: Map<Function, TableMeta> = new Map<Function, TableMeta>();
  private drafts: Map<Object, TableMeta> = new Map<Object, TableMeta>();

  private getOrCreateDraft(proto: Object): TableMeta {
    let draft: TableMeta | undefined = this.drafts.get(proto);
    if (draft === undefined) {
      // entityClass is a temporary placeholder; replaced with the real constructor at finalize.
      draft = new TableMeta(Object as Function);
      this.drafts.set(proto, draft);
    }
    return draft;
  }

  /** For property decorators: find-or-create a ColumnMeta by propertyKey. */
  getOrCreateColumn(proto: Object, propertyKey: string): ColumnMeta {
    const draft: TableMeta = this.getOrCreateDraft(proto);
    let col: ColumnMeta | undefined = draft.columns.get(propertyKey);
    if (col === undefined) {
      col = new ColumnMeta(propertyKey);
      draft.columns.set(propertyKey, col);
    }
    return col;
  }

  /** For relation decorators (@OneToMany/@ManyToOne/@EagerLoad): find-or-create. */
  getOrCreateRelation(proto: Object, propertyKey: string): RelationMeta {
    const draft: TableMeta = this.getOrCreateDraft(proto);
    let rel: RelationMeta | undefined = draft.relations.get(propertyKey);
    if (rel === undefined) {
      rel = new RelationMeta(propertyKey);
      draft.relations.set(propertyKey, rel);
    }
    return rel;
  }

  /** For the `@Index` property decorator: an index record whose resolution is deferred to finalize. */
  stagePropertyIndex(proto: Object, propertyKey: string, name: string | undefined, unique: boolean): void {
    const draft: TableMeta = this.getOrCreateDraft(proto);
    draft.pendingPropertyIndexes.push(new PendingPropertyIndex(propertyKey, name, unique));
  }

  /** For the `@Table` class decorator: resolves the draft and moves it to the final map. */
  finalizeTable(ctor: Function, tableName: string, indexes?: TableIndexOption[]): void {
    const proto: Object = (ctor as Function).prototype as Object;
    const draft: TableMeta = this.getOrCreateDraft(proto);
    draft.entityClass = ctor;
    draft.tableName = tableName;

    // Resolve property-level @Index entries now that columnName + table name are known.
    for (const pending of draft.pendingPropertyIndexes) {
      const col: ColumnMeta | undefined = draft.columns.get(pending.propertyKey);
      const colName: string = col !== undefined ? col.columnName : pending.propertyKey;
      const idxName: string = pending.name !== undefined ? pending.name : `idx_${tableName}_${colName}`;
      draft.indexes.push(new IndexMeta(idxName, [colName], pending.unique));
    }

    // Add table-level (composite) @Table({ indexes }) definitions.
    if (indexes !== undefined) {
      for (const opt of indexes) {
        const idxName: string = opt.name !== undefined ? opt.name : `idx_${tableName}_${opt.columns.join('_')}`;
        const isUnique: boolean = opt.unique !== undefined ? opt.unique : false;
        draft.indexes.push(new IndexMeta(idxName, opt.columns, isUnique));
      }
    }

    if (draft.columns.size === 0) {
      throw new Error(`ArkORM: entity '${tableName}' has no @Column properties.`);
    }

    draft.finalized = true;
    this.tables.set(ctor, draft);
    this.drafts.delete(proto);
  }

  /** Returns finalized metadata; throws a descriptive error if missing. */
  get(entity: Function): TableMeta {
    const meta: TableMeta | undefined = this.tables.get(entity);
    if (meta === undefined || !meta.finalized) {
      throw new Error(`ArkORM: no @Table metadata for '${entity.name}'. Did you forget to add @Table()?`);
    }
    return meta;
  }

  tryGet(entity: Function): TableMeta | undefined {
    return this.tables.get(entity);
  }

  has(entity: Function): boolean {
    return this.tables.has(entity);
  }

  getColumns(entity: Function): ColumnMeta[] {
    return this.get(entity).getColumns();
  }

  getColumn(entity: Function, propertyKey: string): ColumnMeta | undefined {
    return this.get(entity).getColumn(propertyKey);
  }

  getPrimaryKeys(entity: Function): ColumnMeta[] {
    return this.get(entity).getPrimaryKeys();
  }

  getTableName(entity: Function): string {
    return this.get(entity).tableName;
  }

  /** Low-level insertion (test / advanced usage). */
  register(meta: TableMeta): void {
    meta.finalized = true;
    this.tables.set(meta.entityClass, meta);
  }

  /** Clears all metadata for test isolation. */
  clear(): void {
    this.tables.clear();
    this.drafts.clear();
  }

  size(): number {
    return this.tables.size;
  }

  entities(): Function[] {
    const arr: Function[] = [];
    for (const key of this.tables.keys()) {
      arr.push(key);
    }
    return arr;
  }
}

/**
 * Module-level singleton. The import graph (entity → decorator → registry)
 * guarantees this module is initialized before any decorator runs.
 */
export const metadataRegistry: MetadataRegistry = new MetadataRegistry();
