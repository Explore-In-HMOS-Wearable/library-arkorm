import { ColumnMeta, DefaultValue, ForeignKeyMeta, IndexMeta, TableMeta } from '../types/Metadata';
import { columnTypeToSqlite } from '../types/ColumnType';
import { foreignKeyActionToSql } from '../types/ForeignKeyAction';
import { metadataRegistry } from './MetadataRegistry';

/**
 * `TableMeta` → SQL DDL generator. The generated statements are idempotent
 * (`IF NOT EXISTS`), so re-running is safe.
 */
export class DdlGenerator {
  /** Converts a `DefaultValue` into an SQL literal to embed in DDL. */
  private static formatDefault(value: DefaultValue): string {
    if (value === null) {
      return 'NULL';
    }
    if (typeof value === 'string') {
      return `'${value.replace(/'/g, "''")}'`;
    }
    if (typeof value === 'boolean') {
      return value ? '1' : '0';
    }
    return `${value}`;
  }

  /** Generates a single column's definition within `CREATE TABLE`. */
  private static buildColumnDef(col: ColumnMeta, isSingleAutoPk: boolean): string {
    let def: string = `${col.columnName} ${columnTypeToSqlite(col.type)}`;
    if (isSingleAutoPk) {
      // In SQLite auto-increment only works with a column-level INTEGER PRIMARY KEY.
      def += ' PRIMARY KEY AUTOINCREMENT';
    } else {
      if (!col.nullable && !col.isPrimaryKey) {
        def += ' NOT NULL';
      }
      if (col.unique) {
        def += ' UNIQUE';
      }
      if (col.defaultValue !== undefined) {
        def += ` DEFAULT ${DdlGenerator.formatDefault(col.defaultValue)}`;
      }
    }
    return def;
  }

  /** Generates the `CREATE TABLE IF NOT EXISTS` statement for an entity. */
  static buildCreateTable(meta: TableMeta): string {
    const pks: ColumnMeta[] = meta.getPrimaryKeys();
    const isSingleAutoPk: boolean = pks.length === 1 && pks[0].autoGenerate;

    const columnDefs: string[] = [];
    for (const col of meta.getColumns()) {
      const colIsSingleAutoPk: boolean = isSingleAutoPk && col.isPrimaryKey;
      columnDefs.push(DdlGenerator.buildColumnDef(col, colIsSingleAutoPk));
    }

    // Composite PK or non-auto single PK → table-level PRIMARY KEY constraint.
    if (!isSingleAutoPk && pks.length > 0) {
      const pkCols: string[] = pks.map((c: ColumnMeta): string => c.columnName);
      columnDefs.push(`PRIMARY KEY (${pkCols.join(', ')})`);
    }

    // FOREIGN KEY constraints (columns with @ForeignKey).
    for (const col of meta.getColumns()) {
      if (col.foreignKey !== undefined) {
        const fk: ForeignKeyMeta = col.foreignKey;
        const targetTable: string = metadataRegistry.get(fk.targetEntity()).tableName;
        columnDefs.push(
          `FOREIGN KEY (${fk.childColumn}) REFERENCES ${targetTable}(${fk.parentColumn}) ON DELETE ${foreignKeyActionToSql(fk.onDelete)}`
        );
      }
    }

    return `CREATE TABLE IF NOT EXISTS ${meta.tableName} (${columnDefs.join(', ')})`;
  }

  /**
   * Single column-add statement for migration.
   * SQLite ADD COLUMN constraints: PRIMARY KEY / UNIQUE cannot be added; NOT NULL
   * is only possible with a DEFAULT (otherwise added as nullable).
   */
  static buildAddColumn(meta: TableMeta, col: ColumnMeta): string {
    let def: string = `${col.columnName} ${columnTypeToSqlite(col.type)}`;
    if (col.defaultValue !== undefined) {
      if (!col.nullable) {
        def += ' NOT NULL';
      }
      def += ` DEFAULT ${DdlGenerator.formatDefault(col.defaultValue)}`;
    }
    return `ALTER TABLE ${meta.tableName} ADD COLUMN ${def}`;
  }

  /** Generates `CREATE INDEX` statements for all of an entity's indexes. */
  static buildCreateIndexes(meta: TableMeta): string[] {
    const statements: string[] = [];
    for (const idx of meta.indexes) {
      const unique: string = idx.unique ? 'UNIQUE ' : '';
      statements.push(
        `CREATE ${unique}INDEX IF NOT EXISTS ${idx.name} ON ${meta.tableName} (${idx.columns.join(', ')})`
      );
    }
    return statements;
  }
}
