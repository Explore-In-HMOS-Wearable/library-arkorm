import { metadataRegistry } from '../core/MetadataRegistry';
import { ColumnMeta } from '../types/Metadata';

/**
 * `@Unique(value?)` — column-level UNIQUE constraint. Defaults to `true`.
 */
export function Unique(value: boolean = true): (target: Object, propertyKey: string) => void {
  return (target: Object, propertyKey: string): void => {
    const col: ColumnMeta = metadataRegistry.getOrCreateColumn(target, propertyKey);
    col.unique = value;
  };
}
