import { metadataRegistry } from '../core/MetadataRegistry';
import { RelationMeta, RelationType } from '../types/Metadata';

export interface OneToManyOptions {
  targetEntity: () => Function;  // entity on the "many" side (thunk — circular-import safety)
  mappedBy: string;              // inverse @ManyToOne property name on the target entity
}

/**
 * `@OneToMany({ targetEntity, mappedBy })` — one-to-many relation. The relation
 * field (e.g. `posts: Post[]`) is NOT a DB column; loading is done via RelationLoader.
 */
export function OneToMany(options: OneToManyOptions): (target: Object, propertyKey: string) => void {
  return (target: Object, propertyKey: string): void => {
    const rel: RelationMeta = metadataRegistry.getOrCreateRelation(target, propertyKey);
    rel.type = RelationType.ONE_TO_MANY;
    rel.targetEntity = options.targetEntity;
    rel.mappedBy = options.mappedBy;
  };
}
