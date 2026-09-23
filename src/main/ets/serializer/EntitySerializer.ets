import { relationalStore } from '@kit.ArkData';
import { ColumnMeta, TableMeta } from '../types/Metadata';
import { ColumnType } from '../types/ColumnType';

/**
 * Entity → `ValuesBucket` converter.
 *
 * For dynamic string-key access on a statically-typed instance under ArkTS
 * strict mode, we use HarmonyOS RDB's own idiom: since `ValuesBucket` is
 * already `Record<string, ValueType>`, the entity is made readable via
 * `as object as Record<...>`.
 */
export class EntitySerializer {
  /**
   * @param skipPropertyKeys Property names not written to the bucket
   *   (auto-PK on insert, all PKs on update).
   */
  static serialize<T>(entity: T, meta: TableMeta, skipPropertyKeys: string[]): relationalStore.ValuesBucket {
    const source: Record<string, Object | null> = entity as object as Record<string, Object | null>;
    const bucket: relationalStore.ValuesBucket = {};

    for (const col of meta.getColumns()) {
      if (skipPropertyKeys.includes(col.propertyKey)) {
        continue;
      }

      const raw: Object | null = source[col.propertyKey];
      if (raw === null) {
        if (col.nullable) {
          bucket[col.columnName] = null;
        }
        // Skip when not nullable → column default / constraint takes effect.
        continue;
      }

      bucket[col.columnName] = EntitySerializer.toDbValue(col, raw);
    }

    return bucket;
  }

  private static toDbValue(col: ColumnMeta, raw: Object): relationalStore.ValueType {
    if (col.converter !== undefined) {
      return col.converter.convertToDatabaseValue(raw);
    }
    if (col.type === ColumnType.BOOL) {
      return (raw as boolean) ? 1 : 0;
    }
    return raw as relationalStore.ValueType;
  }
}
