import { metadataRegistry } from '../core/MetadataRegistry';
import { RelationMeta, RelationType } from '../types/Metadata';

export interface ManyToOneOptions {
  targetEntity: () => Function;  // entity on the "one" side (thunk — circular-import safety)
  joinColumn: string;            // FK column name on this entity
}

/**
 * `@ManyToOne({ targetEntity, joinColumn })` — many-to-one relation. The relation
 * field (e.g. `author: User | null`) is NOT a DB column; the FK value is stored in
 * the `joinColumn` column, and loading is done via RelationLoader.
 */
export function ManyToOne(options: ManyToOneOptions): (target: Object, propertyKey: string) => void {
  return (target: Object, propertyKey: string): void => {
    const rel: RelationMeta = metadataRegistry.getOrCreateRelation(target, propertyKey);
    rel.type = RelationType.MANY_TO_ONE;
    rel.targetEntity = options.targetEntity;
    rel.joinColumn = options.joinColumn;
  };
}
