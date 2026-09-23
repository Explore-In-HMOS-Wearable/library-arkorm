import { relationalStore } from '@kit.ArkData';
import { metadataRegistry } from '../core/MetadataRegistry';
import { ColumnMeta, RelationMeta, RelationType, TableMeta } from '../types/Metadata';
import { EntityDeserializer } from '../serializer/EntityDeserializer';

/**
 * Relation loader. Loads a single level (no automatic recursion → no circular
 * reference problem). Since entities are plain data objects, the relation field
 * is written via a `Record` cast.
 */
export class RelationLoader {
  /**
   * Loads the `relationName` relation of the `owner` entity and writes it back onto the owner.
   */
  static async load(store: relationalStore.RdbStore, ownerMeta: TableMeta, owner: Object, relationName: string): Promise<void> {
    const rel: RelationMeta | undefined = ownerMeta.getRelation(relationName);
    if (rel === undefined) {
      throw new Error(`ArkORM: '${relationName}' relation does not exist on '${ownerMeta.tableName}'.`);
    }
    const targetMeta: TableMeta = metadataRegistry.get(rel.targetEntity());
    const ownerRec: Record<string, Object | null> = owner as object as Record<string, Object | null>;

    if (rel.type === RelationType.MANY_TO_ONE) {
      await RelationLoader.loadManyToOne(store, ownerMeta, targetMeta, rel, ownerRec, relationName);
    } else {
      await RelationLoader.loadOneToMany(store, ownerMeta, targetMeta, rel, ownerRec, relationName);
    }
  }

  private static async loadManyToOne(store: relationalStore.RdbStore, ownerMeta: TableMeta,
    targetMeta: TableMeta, rel: RelationMeta, ownerRec: Record<string, Object | null>, relationName: string): Promise<void> {
    // The FK value is in the owner's joinColumn column.
    const fkCol: ColumnMeta | undefined = ownerMeta.getColumnByName(rel.joinColumn);
    const fkPropertyKey: string = fkCol !== undefined ? fkCol.propertyKey : rel.joinColumn;
    const fkValue: Object | null = ownerRec[fkPropertyKey];
    if (fkValue === null) {
      ownerRec[relationName] = null;
      return;
    }
    const targetPk: ColumnMeta[] = targetMeta.getPrimaryKeys();
    if (targetPk.length === 0) {
      throw new Error(`ArkORM: table '${targetMeta.tableName}' has no PK (required for @ManyToOne).`);
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(targetMeta.tableName);
    predicates.equalTo(targetPk[0].columnName, fkValue as relationalStore.ValueType);
    const rs: relationalStore.ResultSet = await store.query(predicates);
    const rows: Object[] = EntityDeserializer.deserializeAll<Object>(rs, targetMeta);
    rs.close();
    ownerRec[relationName] = rows.length > 0 ? rows[0] : null;
  }

  private static async loadOneToMany(store: relationalStore.RdbStore, ownerMeta: TableMeta,
    targetMeta: TableMeta, rel: RelationMeta, ownerRec: Record<string, Object | null>, relationName: string): Promise<void> {
    const ownerPk: ColumnMeta[] = ownerMeta.getPrimaryKeys();
    if (ownerPk.length === 0) {
      throw new Error(`ArkORM: table '${ownerMeta.tableName}' has no PK (required for @OneToMany).`);
    }
    const ownerId: Object | null = ownerRec[ownerPk[0].propertyKey];

    // The joinColumn of the inverse @ManyToOne on the target = FK column.
    const backRel: RelationMeta | undefined = targetMeta.getRelation(rel.mappedBy);
    if (backRel === undefined) {
      throw new Error(`ArkORM: relation mappedBy='${rel.mappedBy}' not found on '${targetMeta.tableName}'.`);
    }

    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(targetMeta.tableName);
    predicates.equalTo(backRel.joinColumn, ownerId as relationalStore.ValueType);
    const rs: relationalStore.ResultSet = await store.query(predicates);
    const rows: Object[] = EntityDeserializer.deserializeAll<Object>(rs, targetMeta);
    rs.close();
    ownerRec[relationName] = rows as Object;
  }
}
