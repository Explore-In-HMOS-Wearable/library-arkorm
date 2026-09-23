import { relationalStore } from '@kit.ArkData';
import { ColumnMeta, TableMeta } from '../types/Metadata';
import { ColumnType } from '../types/ColumnType';

/**
 * `ResultSet` → entity converter.
 *
 * Because of ArkTS `arkts-no-ctor-signatures-funcs`, `new entityClass()` via a
 * generic constructor is not possible. Instead a plain object (`Record`) is
 * built and cast to the target type — this is behaviorally equivalent since
 * ArkORM entities only hold data (contain no methods). The caller supplies the
 * type argument explicitly: `deserializeAll<User>(rs, meta)`.
 */
export class EntityDeserializer {
  /** Builds a single entity from the cursor's current row. */
  static deserialize<T>(rs: relationalStore.ResultSet, meta: TableMeta): T {
    const target: Record<string, Object | null> = {};

    for (const col of meta.getColumns()) {
      const idx: number = rs.getColumnIndex(col.columnName);
      if (idx < 0) {
        continue;
      }
      if (rs.isColumnNull(idx)) {
        target[col.propertyKey] = null;
        continue;
      }
      target[col.propertyKey] = EntityDeserializer.fromDbValue(col, rs, idx);
    }

    return target as object as T;
  }

  /** Iterates the cursor over all rows to build an entity array. */
  static deserializeAll<T>(rs: relationalStore.ResultSet, meta: TableMeta): T[] {
    const result: T[] = [];
    while (rs.goToNextRow()) {
      result.push(EntityDeserializer.deserialize<T>(rs, meta));
    }
    return result;
  }

  private static fromDbValue(col: ColumnMeta, rs: relationalStore.ResultSet, idx: number): Object {
    if (col.converter !== undefined) {
      const raw: relationalStore.ValueType = EntityDeserializer.rawByType(col, rs, idx);
      return col.converter.convertToEntityProperty(raw);
    }
    if (col.type === ColumnType.BOOL) {
      return rs.getLong(idx) === 1;
    }
    return EntityDeserializer.rawByType(col, rs, idx) as Object;
  }

  /** Calls the appropriate ResultSet getter based on the column type. */
  private static rawByType(col: ColumnMeta, rs: relationalStore.ResultSet, idx: number): relationalStore.ValueType {
    switch (col.type) {
      case ColumnType.INT:
      case ColumnType.BOOL:
        return rs.getLong(idx);
      case ColumnType.REAL:
      case ColumnType.DOUBLE:
        return rs.getDouble(idx);
      case ColumnType.BLOB:
        return rs.getBlob(idx);
      case ColumnType.STR:
      default:
        return rs.getString(idx);
    }
  }
}
