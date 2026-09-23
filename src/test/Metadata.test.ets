import { describe, it, expect } from '@ohos/hypium';
import { Table } from '../main/ets/annotation/Table';
import { Column } from '../main/ets/annotation/Column';
import { PrimaryKey } from '../main/ets/annotation/PrimaryKey';
import { Unique } from '../main/ets/annotation/Unique';
import { Index } from '../main/ets/annotation/Index';
import { ColumnType, columnTypeToSqlite } from '../main/ets/types/ColumnType';
import { ColumnMeta, IndexMeta, TableMeta } from '../main/ets/types/Metadata';
import { metadataRegistry } from '../main/ets/core/MetadataRegistry';

@Table({
  name: 'users',
  indexes: [{ columns: ['email'], unique: true, name: 'idx_users_email' }]
})
class TestUser {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  @Column({ type: ColumnType.STR, name: 'full_name' })
  name: string = '';

  @Unique()
  @Column({ type: ColumnType.STR })
  email: string = '';

  @Index({ unique: false })
  @Column({ type: ColumnType.INT, nullable: true, defaultValue: null })
  age: number | null = null;
}

class NoTableEntity {
  @Column({ type: ColumnType.STR })
  name: string = '';
}

export default function metadataTest() {
  describe('ArkORM_Metadata', () => {

    it('table_registered_and_keyed_by_constructor', 0, () => {
      expect(metadataRegistry.has(TestUser)).assertTrue();
      const meta: TableMeta = metadataRegistry.get(TestUser);
      expect(meta.tableName).assertEqual('users');
      expect(meta.entityClass === TestUser).assertTrue();
    });

    it('columns_count_and_name_mapping', 0, () => {
      const cols: ColumnMeta[] = metadataRegistry.getColumns(TestUser);
      expect(cols.length).assertEqual(4);
      expect(metadataRegistry.getColumn(TestUser, 'name')!.columnName).assertEqual('full_name');
      expect(metadataRegistry.getColumn(TestUser, 'id')!.columnName).assertEqual('id');
    });

    it('stacked_primarykey_and_column_merge_one_columnmeta', 0, () => {
      const id: ColumnMeta = metadataRegistry.getColumn(TestUser, 'id')!;
      expect(id.isPrimaryKey).assertTrue();
      expect(id.autoGenerate).assertTrue();
      expect(id.type).assertEqual(ColumnType.INT);
      expect(metadataRegistry.getPrimaryKeys(TestUser).length).assertEqual(1);
    });

    it('unique_nullable_and_default', 0, () => {
      expect(metadataRegistry.getColumn(TestUser, 'email')!.unique).assertTrue();
      const age: ColumnMeta = metadataRegistry.getColumn(TestUser, 'age')!;
      expect(age.nullable).assertTrue();
      expect(age.defaultValue).assertEqual(null);
    });

    it('table_level_index_resolved', 0, () => {
      const meta: TableMeta = metadataRegistry.get(TestUser);
      const emailIdx: IndexMeta | undefined =
        meta.indexes.find((i: IndexMeta): boolean => i.name === 'idx_users_email');
      expect(emailIdx !== undefined).assertTrue();
      expect(emailIdx!.unique).assertTrue();
      expect(emailIdx!.columns[0]).assertEqual('email');
    });

    it('property_level_index_name_generated', 0, () => {
      const meta: TableMeta = metadataRegistry.get(TestUser);
      const ageIdx: IndexMeta | undefined =
        meta.indexes.find((i: IndexMeta): boolean => i.columns.length === 1 && i.columns[0] === 'age');
      expect(ageIdx !== undefined).assertTrue();
      expect(ageIdx!.name).assertEqual('idx_users_age');
    });

    it('columntype_to_sqlite_mapping', 0, () => {
      expect(columnTypeToSqlite(ColumnType.BOOL)).assertEqual('INTEGER');
      expect(columnTypeToSqlite(ColumnType.INT)).assertEqual('INTEGER');
      expect(columnTypeToSqlite(ColumnType.STR)).assertEqual('TEXT');
      expect(columnTypeToSqlite(ColumnType.DOUBLE)).assertEqual('REAL');
      expect(columnTypeToSqlite(ColumnType.REAL)).assertEqual('REAL');
      expect(columnTypeToSqlite(ColumnType.BLOB)).assertEqual('BLOB');
    });

    it('missing_table_throws', 0, () => {
      let threw: boolean = false;
      try {
        metadataRegistry.get(NoTableEntity);
      } catch (e) {
        threw = true;
      }
      expect(threw).assertTrue();
      expect(metadataRegistry.has(NoTableEntity)).assertFalse();
    });
  });
}
