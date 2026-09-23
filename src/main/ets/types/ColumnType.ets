/**
 * ArkORM — supported logical column types.
 *
 * A string-valued enum is used (instead of numeric) so the values stay
 * readable in logs/tests. `BOOL` is kept distinct from `INT`: even though
 * its SQLite affinity is the same (INTEGER), the serializer must know the
 * logical distinction for the 0/1 conversion.
 */
export enum ColumnType {
  INT = 'INT',       // 64-bit integer
  STR = 'STR',       // text
  REAL = 'REAL',     // floating point
  DOUBLE = 'DOUBLE', // REAL affinity, distinct logical type
  BLOB = 'BLOB',     // Uint8Array
  BOOL = 'BOOL'      // stored as 0/1, INTEGER affinity
}

/**
 * Converts the logical `ColumnType` to the SQLite type affinity used in DDL generation.
 */
export function columnTypeToSqlite(type: ColumnType): string {
  switch (type) {
    case ColumnType.INT:
      return 'INTEGER';
    case ColumnType.STR:
      return 'TEXT';
    case ColumnType.REAL:
      return 'REAL';
    case ColumnType.DOUBLE:
      return 'REAL';
    case ColumnType.BLOB:
      return 'BLOB';
    case ColumnType.BOOL:
      return 'INTEGER';
    default:
      return 'TEXT';
  }
}
