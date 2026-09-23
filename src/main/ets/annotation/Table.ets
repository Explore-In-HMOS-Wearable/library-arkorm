import { metadataRegistry } from '../core/MetadataRegistry';
import { TableIndexOption } from '../types/Metadata';

export interface TableOptions {
  name: string;
  indexes?: TableIndexOption[];
}

/**
 * `@Table({ name, indexes? })` — maps a class to a database table.
 *
 * As a class decorator it runs AFTER property decorators, which is why
 * it is the right place to finalize the staging draft.
 */
export function Table(options: TableOptions): (target: Function) => void {
  return (target: Function): void => {
    metadataRegistry.finalizeTable(target, options.name, options.indexes);
  };
}
