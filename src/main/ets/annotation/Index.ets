import { metadataRegistry } from '../core/MetadataRegistry';

export interface IndexOptions {
  name?: string;
  unique?: boolean;
}

/**
 * `@Index({ name?, unique? })` — single-column index on a property.
 *
 * Resolution is deferred to finalize: if a custom column name is given via
 * `@Column({ name })`, it is used correctly whether it runs before or after `@Index`.
 */
export function Index(options?: IndexOptions): (target: Object, propertyKey: string) => void {
  return (target: Object, propertyKey: string): void => {
    const name: string | undefined = options !== undefined ? options.name : undefined;
    const unique: boolean = (options !== undefined && options.unique !== undefined) ? options.unique : false;
    metadataRegistry.stagePropertyIndex(target, propertyKey, name, unique);
  };
}
