import { ColumnType } from './ColumnType';
import { ForeignKeyAction } from './ForeignKeyAction';
import { PropertyConverter } from '../serializer/PropertyConverter';

/**
 * Literal types a column's `defaultValue` may take.
 * An explicit union is used because `any` is forbidden in ArkTS.
 * `null` → "DEFAULT NULL"; `undefined` → "no default" (distinct meanings).
 */
export type DefaultValue = string | number | boolean | null;

/**
 * Table-level (composite) index definition inside `@Table({ indexes: [...] })`.
 *
 * Defined here (in the types layer) to avoid an import cycle:
 * `core/MetadataRegistry` uses it but must not depend on `annotation/Table`.
 */
export interface TableIndexOption {
  columns: string[];
  unique?: boolean;
  name?: string;
}

/**
 * Resolved metadata for a single column. Filled incrementally by the
 * decorators (via upsert keyed on propertyKey).
 */
export class ColumnMeta {
  propertyKey: string;
  columnName: string;
  type: ColumnType = ColumnType.STR;
  nullable: boolean = false;
  defaultValue: DefaultValue | undefined = undefined;
  isPrimaryKey: boolean = false;
  autoGenerate: boolean = false;
  unique: boolean = false;
  converter: PropertyConverter | undefined = undefined;
  foreignKey: ForeignKeyMeta | undefined = undefined;

  constructor(propertyKey: string) {
    this.propertyKey = propertyKey;
    this.columnName = propertyKey;
  }
}

/**
 * `@ForeignKey` metadata (produces a FOREIGN KEY constraint in DDL).
 * `targetEntity` is a THUNK (`() => Entity`) for circular-import safety
 * (the reference is resolved at call time, after the modules are loaded).
 */
export class ForeignKeyMeta {
  targetEntity: () => Function;
  parentColumn: string;
  childColumn: string;
  onDelete: ForeignKeyAction;

  constructor(targetEntity: () => Function, parentColumn: string, childColumn: string, onDelete: ForeignKeyAction) {
    this.targetEntity = targetEntity;
    this.parentColumn = parentColumn;
    this.childColumn = childColumn;
    this.onDelete = onDelete;
  }
}

/** Relation type. */
export enum RelationType {
  ONE_TO_MANY,
  MANY_TO_ONE
}

/**
 * `@OneToMany` / `@ManyToOne` relation metadata.
 * - MANY_TO_ONE: `joinColumn` = the FK column name on this entity.
 * - ONE_TO_MANY: `mappedBy` = the inverse @ManyToOne property name on the target entity.
 */
export class RelationMeta {
  propertyKey: string;
  type: RelationType = RelationType.MANY_TO_ONE;
  // THUNK — resolved at call time for circular-import safety.
  targetEntity: () => Function = (): Function => Object as Function;
  joinColumn: string = '';
  mappedBy: string = '';
  eager: boolean = false;

  constructor(propertyKey: string) {
    this.propertyKey = propertyKey;
  }
}

/** Resolved index metadata (used in DDL generation). */
export class IndexMeta {
  name: string;
  columns: string[];
  unique: boolean;

  constructor(name: string, columns: string[], unique: boolean) {
    this.name = name;
    this.columns = columns;
    this.unique = unique;
  }
}

/**
 * Staging record for a property-level `@Index`.
 * Held here because `columnName` and the default index name cannot be
 * resolved until the table name is known (at finalize).
 */
export class PendingPropertyIndex {
  propertyKey: string;
  name: string | undefined;
  unique: boolean;

  constructor(propertyKey: string, name: string | undefined, unique: boolean) {
    this.propertyKey = propertyKey;
    this.name = name;
    this.unique = unique;
  }
}

/**
 * Full table metadata for an entity class.
 * `columns` is a `Map` keyed on propertyKey (insertion order ≈ declaration order),
 * so composite PK and column order are preserved.
 */
export class TableMeta {
  entityClass: Function;
  tableName: string = '';
  columns: Map<string, ColumnMeta> = new Map<string, ColumnMeta>();
  relations: Map<string, RelationMeta> = new Map<string, RelationMeta>();
  indexes: IndexMeta[] = [];
  finalized: boolean = false;

  // Used only during the staging phase:
  pendingPropertyIndexes: PendingPropertyIndex[] = [];

  constructor(entityClass: Function) {
    this.entityClass = entityClass;
  }

  getColumns(): ColumnMeta[] {
    const arr: ColumnMeta[] = [];
    for (const col of this.columns.values()) {
      arr.push(col);
    }
    return arr;
  }

  getColumn(propertyKey: string): ColumnMeta | undefined {
    return this.columns.get(propertyKey);
  }

  /** Finds a column by DB column name (not property key). */
  getColumnByName(columnName: string): ColumnMeta | undefined {
    for (const col of this.columns.values()) {
      if (col.columnName === columnName) {
        return col;
      }
    }
    return undefined;
  }

  getRelation(propertyKey: string): RelationMeta | undefined {
    return this.relations.get(propertyKey);
  }

  getPrimaryKeys(): ColumnMeta[] {
    return this.getColumns().filter((c: ColumnMeta): boolean => c.isPrimaryKey);
  }
}
