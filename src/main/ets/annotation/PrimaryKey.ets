import { metadataRegistry } from '../core/MetadataRegistry';
import { ColumnMeta } from '../types/Metadata';

export interface PrimaryKeyOptions {
  autoGenerate?: boolean;
}

/**
 * `@PrimaryKey({ autoGenerate? })` — marks a property as the primary key.
 *
 * Can be stacked with `@Column` on the same property; order does not matter
 * because the registry upserts by propertyKey (both write to the same ColumnMeta).
 */
export function PrimaryKey(options?: PrimaryKeyOptions): (target: Object, propertyKey: string) => void {
  return (target: Object, propertyKey: string): void => {
    const col: ColumnMeta = metadataRegistry.getOrCreateColumn(target, propertyKey);
    col.isPrimaryKey = true;
    col.autoGenerate = (options !== undefined && options.autoGenerate !== undefined) ? options.autoGenerate : false;
  };
}
