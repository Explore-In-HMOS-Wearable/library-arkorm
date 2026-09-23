import { relationalStore } from '@kit.ArkData';
import { ColumnMeta, TableMeta } from '../types/Metadata';
import { DdlGenerator } from '../core/DdlGenerator';

/**
 * Compares the live DB schema with the metadata (for automatic migration).
 * The DB side is read via `PRAGMA table_info` and `sqlite_master`.
 */
export class SchemaDiff {
  /** Returns whether a table exists. */
  static async tableExists(store: relationalStore.RdbStore, tableName: string): Promise<boolean> {
    const rs: relationalStore.ResultSet =
      await store.querySql("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [tableName]);
    const exists: boolean = rs.goToNextRow();
    rs.close();
    return exists;
  }

  /** Returns the existing column names in a table. */
  static async getTableColumns(store: relationalStore.RdbStore, tableName: string): Promise<Set<string>> {
    const columns: Set<string> = new Set<string>();
    const rs: relationalStore.ResultSet = await store.querySql(`PRAGMA table_info(${tableName})`, []);
    const nameIdx: number = rs.getColumnIndex('name');
    while (rs.goToNextRow()) {
      columns.add(rs.getString(nameIdx));
    }
    rs.close();
    return columns;
  }

  /**
   * Generates `ALTER TABLE ADD COLUMN` statements for columns present in the
   * metadata but missing from the DB.
   */
  static async missingColumnDdl(store: relationalStore.RdbStore, meta: TableMeta): Promise<string[]> {
    const existing: Set<string> = await SchemaDiff.getTableColumns(store, meta.tableName);
    const statements: string[] = [];
    for (const col of meta.getColumns()) {
      if (!existing.has(col.columnName)) {
        statements.push(DdlGenerator.buildAddColumn(meta, col));
      }
    }
    return statements;
  }
}
