import { describe, it, expect } from '@ohos/hypium';
import { Table } from '../main/ets/annotation/Table';
import { Column } from '../main/ets/annotation/Column';
import { PrimaryKey } from '../main/ets/annotation/PrimaryKey';
import { Unique } from '../main/ets/annotation/Unique';
import { ForeignKey } from '../main/ets/annotation/ForeignKey';
import { ColumnType } from '../main/ets/types/ColumnType';
import { ForeignKeyAction } from '../main/ets/types/ForeignKeyAction';
import { ColumnMeta, TableMeta } from '../main/ets/types/Metadata';
import { metadataRegistry } from '../main/ets/core/MetadataRegistry';
import { DdlGenerator } from '../main/ets/core/DdlGenerator';

@Table({
  name: 'ddl_parent',
  indexes: [{ columns: ['code'], unique: true, name: 'idx_parent_code' }]
})
class DdlParent {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  @Unique()
  @Column({ type: ColumnType.STR })
  code: string = '';

  @Column({ type: ColumnType.INT, nullable: true, defaultValue: 5 })
  score: number | null = null;

  @Column({ type: ColumnType.STR, defaultValue: 'active' })
  status: string = 'active';
}

@Table({ name: 'ddl_child' })
class DdlChild {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  @ForeignKey({ entity: () => DdlParent, parentColumn: 'id', childColumn: 'parentId', onDelete: ForeignKeyAction.CASCADE })
  @Column({ type: ColumnType.INT })
  parentId: number = 0;
}

@Table({ name: 'ddl_composite' })
class DdlComposite {
  @PrimaryKey()
  @Column({ type: ColumnType.INT })
  a: number = 0;

  @PrimaryKey()
  @Column({ type: ColumnType.INT })
  b: number = 0;
}

export default function ddlTest() {
  describe('ArkORM_Ddl', () => {

    it('create_table_auto_pk_unique_default', 0, () => {
      const sql: string = DdlGenerator.buildCreateTable(metadataRegistry.get(DdlParent));
      expect(sql.includes('CREATE TABLE IF NOT EXISTS ddl_parent')).assertTrue();
      expect(sql.includes('id INTEGER PRIMARY KEY AUTOINCREMENT')).assertTrue();
      expect(sql.includes('code TEXT NOT NULL UNIQUE')).assertTrue();
      expect(sql.includes('score INTEGER DEFAULT 5')).assertTrue();
      // status non-null + default.
      expect(sql.includes("status TEXT NOT NULL DEFAULT 'active'")).assertTrue();
    });

    it('create_indexes', 0, () => {
      const idx: string[] = DdlGenerator.buildCreateIndexes(metadataRegistry.get(DdlParent));
      expect(idx.length).assertEqual(1);
      expect(idx[0]).assertEqual('CREATE UNIQUE INDEX IF NOT EXISTS idx_parent_code ON ddl_parent (code)');
    });

    it('create_table_foreign_key', 0, () => {
      const sql: string = DdlGenerator.buildCreateTable(metadataRegistry.get(DdlChild));
      expect(sql.includes('FOREIGN KEY (parentId) REFERENCES ddl_parent(id) ON DELETE CASCADE')).assertTrue();
    });

    it('create_table_composite_pk', 0, () => {
      const sql: string = DdlGenerator.buildCreateTable(metadataRegistry.get(DdlComposite));
      expect(sql.includes('PRIMARY KEY (a, b)')).assertTrue();
      expect(sql.includes('AUTOINCREMENT')).assertFalse();
    });

    it('add_column_alter', 0, () => {
      const meta: TableMeta = metadataRegistry.get(DdlParent);
      const score: ColumnMeta = meta.getColumn('score')!;
      const status: ColumnMeta = meta.getColumn('status')!;
      expect(DdlGenerator.buildAddColumn(meta, score)).assertEqual('ALTER TABLE ddl_parent ADD COLUMN score INTEGER DEFAULT 5');
      expect(DdlGenerator.buildAddColumn(meta, status)).assertEqual("ALTER TABLE ddl_parent ADD COLUMN status TEXT NOT NULL DEFAULT 'active'");
    });
  });
}
