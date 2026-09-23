import { describe, beforeAll, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';

import { Table } from '../../../main/ets/annotation/Table';
import { Column } from '../../../main/ets/annotation/Column';
import { PrimaryKey } from '../../../main/ets/annotation/PrimaryKey';
import { Database } from '../../../main/ets/annotation/Database';
import { ArkORM } from '../../../main/ets/core/ArkORM';
import { ArkORMDatabase } from '../../../main/ets/core/ArkORMDatabase';
import { ColumnType } from '../../../main/ets/types/ColumnType';
import { TableMeta } from '../../../main/ets/types/Metadata';
import { metadataRegistry } from '../../../main/ets/core/MetadataRegistry';
import { SchemaDiff } from '../../../main/ets/migration/SchemaDiff';

const DB_NAME: string = 'arkorm_mig_test.db';

@Table({ name: 'mig_users' })
class MigUser {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  @Column({ type: ColumnType.STR })
  name: string = '';

  @Column({ type: ColumnType.STR, nullable: true })
  email: string | null = null;

  @Column({ type: ColumnType.INT, nullable: true })
  age: number | null = null;
}

@Database({ entities: [MigUser], name: DB_NAME, version: 1 })
class TestMigDb {
}

export default function migrationTest() {
  describe('ArkORM_Migration', () => {
    let db: ArkORMDatabase;

    beforeAll(async () => {
      const delegator: abilityDelegatorRegistry.AbilityDelegator =
        abilityDelegatorRegistry.getAbilityDelegator();
      const context: common.Context = delegator.getAppContext() as common.Context;
      await relationalStore.deleteRdbStore(context, DB_NAME);
      await ArkORM.init(context, TestMigDb);
      db = ArkORM.getDatabase(TestMigDb);
    });

    it('table_exists', 0, async () => {
      expect(await SchemaDiff.tableExists(db.rdbStore, 'mig_users')).assertTrue();
      expect(await SchemaDiff.tableExists(db.rdbStore, 'yok_boyle_tablo')).assertFalse();
    });

    it('auto_add_missing_columns', 0, async () => {
      const store: relationalStore.RdbStore = db.rdbStore;

      await store.executeSql('DROP TABLE IF EXISTS mig_users');
      await store.executeSql('CREATE TABLE mig_users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)');

      const before: Set<string> = await SchemaDiff.getTableColumns(store, 'mig_users');
      expect(before.has('name')).assertTrue();
      expect(before.has('email')).assertFalse();
      expect(before.has('age')).assertFalse();

      const meta: TableMeta = metadataRegistry.get(MigUser);
      const ddl: string[] = await SchemaDiff.missingColumnDdl(store, meta);
      expect(ddl.length).assertEqual(2);

      for (const sql of ddl) {
        await store.executeSql(sql);
      }

      const after: Set<string> = await SchemaDiff.getTableColumns(store, 'mig_users');
      expect(after.has('email')).assertTrue();
      expect(after.has('age')).assertTrue();

      const u: MigUser = new MigUser();
      u.name = 'Mig';
      u.email = 'mig@x.com';
      u.age = 7;
      const id: number = await db.from<MigUser>(MigUser).insert(u);
      const fetched: MigUser | null = await db.from<MigUser>(MigUser).where('id').eq(id).findOne();
      expect(fetched !== null).assertTrue();
      expect(fetched!.email).assertEqual('mig@x.com');
      expect(fetched!.age).assertEqual(7);
    });
  });
}
