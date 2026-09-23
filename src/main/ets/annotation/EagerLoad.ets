import { metadataRegistry } from '../core/MetadataRegistry';
import { RelationMeta } from '../types/Metadata';

/**
 * `@EagerLoad` — marks a relation to be eagerly (automatically) loaded.
 * Stacks on the same property as `@OneToMany` / `@ManyToOne`; order does not
 * matter (the registry upserts by propertyKey).
 */
export function EagerLoad(target: Object, propertyKey: string): void {
  const rel: RelationMeta = metadataRegistry.getOrCreateRelation(target, propertyKey);
  rel.eager = true;
}
