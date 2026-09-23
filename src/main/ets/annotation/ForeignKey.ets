import { metadataRegistry } from '../core/MetadataRegistry';
import { ColumnMeta, ForeignKeyMeta } from '../types/Metadata';
import { ForeignKeyAction } from '../types/ForeignKeyAction';

export interface ForeignKeyOptions {
  entity: () => Function;    // referenced entity (thunk — circular-import safety)
  parentColumn: string;      // column in the target table (usually the PK)
  childColumn: string;       // FK column name in this table
  onDelete?: ForeignKeyAction;
}

/**
 * `@ForeignKey({ entity, parentColumn, childColumn, onDelete? })` — makes a
 * column a foreign key; generates `FOREIGN KEY ... REFERENCES ...` in the DDL.
 */
export function ForeignKey(options: ForeignKeyOptions): (target: Object, propertyKey: string) => void {
  return (target: Object, propertyKey: string): void => {
    const col: ColumnMeta = metadataRegistry.getOrCreateColumn(target, propertyKey);
    const onDelete: ForeignKeyAction =
      options.onDelete !== undefined ? options.onDelete : ForeignKeyAction.NO_ACTION;
    col.foreignKey = new ForeignKeyMeta(options.entity, options.parentColumn, options.childColumn, onDelete);
  };
}
