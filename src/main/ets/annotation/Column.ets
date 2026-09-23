import { metadataRegistry } from '../core/MetadataRegistry';
import { ColumnMeta, DefaultValue } from '../types/Metadata';
import { ColumnType } from '../types/ColumnType';

export interface ColumnOptions {
  type: ColumnType;
  name?: string;
  nullable?: boolean;
  defaultValue?: DefaultValue;
}

/**
 * `@Column({ type, name?, nullable?, defaultValue? })` — maps a property
 * to a table column. `target` is the prototype (typed `Object` in ArkTS).
 */
export function Column(options: ColumnOptions): (target: Object, propertyKey: string) => void {
  return (target: Object, propertyKey: string): void => {
    const col: ColumnMeta = metadataRegistry.getOrCreateColumn(target, propertyKey);
    col.type = options.type;
    col.columnName = options.name !== undefined ? options.name : propertyKey;
    col.nullable = options.nullable !== undefined ? options.nullable : false;
    // null is a valid default; only write when not undefined to distinguish from "unset".
    if (options.defaultValue !== undefined) {
      col.defaultValue = options.defaultValue;
    }
  };
}
