import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';

import { Table } from '../../../main/ets/annotation/Table';
import { Column } from '../../../main/ets/annotation/Column';
import { PrimaryKey } from '../../../main/ets/annotation/PrimaryKey';
import { Unique } from '../../../main/ets/annotation/Unique';
import { TypeConverter } from '../../../main/ets/annotation/TypeConverter';
import { Database } from '../../../main/ets/annotation/Database';
import { ArkORM } from '../../../main/ets/core/ArkORM';
import { ArkORMDatabase } from '../../../main/ets/core/ArkORMDatabase';
import { ColumnType } from '../../../main/ets/types/ColumnType';
import { OnConflictStrategy } from '../../../main/ets/types/OnConflictStrategy';
import { DateConverter } from '../../../main/ets/serializer/PropertyConverter';
import { EntityDeserializer } from '../../../main/ets/serializer/EntityDeserializer';
import { metadataRegistry } from '../../../main/ets/core/MetadataRegistry';

const DB_NAME: string = 'arkorm_test.db';

@Table({ name: 'users' })
class TestUser {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  @Column({ type: ColumnType.STR })
  name: string = '';

  @Unique()
  @Column({ type: ColumnType.STR })
  email: string = '';

  @Column({ type: ColumnType.INT, nullable: true })
  age: number | null = null;

  @Column({ type: ColumnType.BOOL })
  active: boolean = true;

  @TypeConverter({ converter: new DateConverter() })
  @Column({ type: ColumnType.INT })
  createdAt: Date = new Date(0);
}

@Database({ entities: [TestUser], name: DB_NAME, version: 1 })
class TestAppDatabase {
}

function makeUser(name: string, email: string, age: number | null): TestUser {
  const u: TestUser = new TestUser();
  u.name = name;
  u.email = email;
  u.age = age;
  u.active = true;
  u.createdAt = new Date(1_700_000_000_000);
  return u;
}

async function queryById(db: ArkORMDatabase, id: number): Promise<TestUser | null> {
  const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('users');
  predicates.equalTo('id', id);
  const rs: relationalStore.ResultSet = await db.rdbStore.query(predicates);
  const rows: TestUser[] = EntityDeserializer.deserializeAll<TestUser>(rs, metadataRegistry.get(TestUser));
  rs.close();
  return rows.length > 0 ? rows[0] : null;
}

export default function crudTest() {
  describe('ArkORM_CRUD', () => {
    let db: ArkORMDatabase;

    beforeAll(async () => {
      const delegator: abilityDelegatorRegistry.AbilityDelegator =
        abilityDelegatorRegistry.getAbilityDelegator();
      const context: common.Context = delegator.getAppContext() as common.Context;

      await relationalStore.deleteRdbStore(context, DB_NAME);
      await ArkORM.init(context, TestAppDatabase);
      db = ArkORM.getDatabase(TestAppDatabase);
    });

    afterAll(async () => {
      await ArkORM.close(TestAppDatabase);
    });

    it('insert_returns_rowid_and_writes_back_pk', 0, async () => {
      const user: TestUser = makeUser('Demo', 'demo@example.com', 30);
      const id: number = await db.from<TestUser>(TestUser).insert(user);
      expect(id > 0).assertTrue();

      expect(user.id).assertEqual(id);
    });

    it('findById_roundtrip_with_typeconverter_and_bool', 0, async () => {
      const user: TestUser = makeUser('Demo 2', 'demo2@example.com', null);
      const id: number = await db.from<TestUser>(TestUser).insert(user);

      const fetched: TestUser | null = await queryById(db, id);
      expect(fetched !== null).assertTrue();
      expect(fetched!.name).assertEqual('Demo 2');
      expect(fetched!.age).assertEqual(null);
      expect(fetched!.active).assertEqual(true);
      // TypeConverter: Date ↔ epoch-millis round-trip.
      expect(fetched!.createdAt instanceof Date).assertTrue();
      expect(fetched!.createdAt.getTime()).assertEqual(1_700_000_000_000);
    });

    it('batch_insert_counts', 0, async () => {
      const batch: TestUser[] = [
        makeUser('B1', 'b1@example.com', 1),
        makeUser('B2', 'b2@example.com', 2),
        makeUser('B3', 'b3@example.com', 3)
      ];
      const inserted: number = await db.from<TestUser>(TestUser).insertAll(batch);
      expect(inserted).assertEqual(3);
    });

    it('update_changes_field', 0, async () => {
      const user: TestUser = makeUser('Old', 'update@example.com', 20);
      const id: number = await db.from<TestUser>(TestUser).insert(user);

      user.name = 'New';
      user.age = 21;
      const affected: number = await db.from<TestUser>(TestUser).update(user);
      expect(affected).assertEqual(1);

      const fetched: TestUser | null = await queryById(db, id);
      expect(fetched!.name).assertEqual('New');
      expect(fetched!.age).assertEqual(21);
    });

    it('delete_removes_row', 0, async () => {
      const user: TestUser = makeUser('WillBeDelete', 'delete@example.com', 40);
      const id: number = await db.from<TestUser>(TestUser).insert(user);

      const affected: number = await db.from<TestUser>(TestUser).delete(user);
      expect(affected).assertEqual(1);

      const fetched: TestUser | null = await queryById(db, id);
      expect(fetched === null).assertTrue();
    });

    it('conflict_ignore_on_duplicate_unique', 0, async () => {
      const first: TestUser = makeUser('İlk', 'dup@example.com', 10);
      await db.from<TestUser>(TestUser).insert(first);

      const dup: TestUser = makeUser('İkinci', 'dup@example.com', 11);

      const id: number = await db.from<TestUser>(TestUser).insert(dup, OnConflictStrategy.IGNORE);
      expect(id < 0).assertTrue();
    });

    it('query_where_orderby_count_findone_exists', 0, async () => {
      await db.rdbStore.executeSql('DELETE FROM users');
      await db.from<TestUser>(TestUser).insertAll([
        makeUser('A', 'a@x.com', 20),
        makeUser('B', 'b@x.com', 30),
        makeUser('C', 'c@x.com', 40)
      ]);

      const adults: TestUser[] = await db.from<TestUser>(TestUser)
        .where('age').gte(30).orderBy('age').findAll();
      expect(adults.length).assertEqual(2);
      expect(adults[0].name).assertEqual('B');
      expect(adults[1].name).assertEqual('C');

      const cnt: number = await db.from<TestUser>(TestUser).where('age').gt(25).count();
      expect(cnt).assertEqual(2);

      const total: number = await db.from<TestUser>(TestUser).count();
      expect(total).assertEqual(3);

      const one: TestUser | null = await db.from<TestUser>(TestUser)
        .where('email').eq('b@x.com').findOne();
      expect(one !== null).assertTrue();
      expect(one!.age).assertEqual(30);

      const exists: boolean = await db.from<TestUser>(TestUser)
        .where('email').eq('zzz@x.com').exists();
      expect(exists).assertFalse();
    });

    it('query_between_like_in_and_page', 0, async () => {
      await db.rdbStore.executeSql('DELETE FROM users');
      await db.from<TestUser>(TestUser).insertAll([
        makeUser('Alice', 'alice@x.com', 18),
        makeUser('Bob', 'bob@x.com', 25),
        makeUser('Carol', 'carol@x.com', 35),
        makeUser('Dave', 'dave@x.com', 45)
      ]);

      const mid: TestUser[] = await db.from<TestUser>(TestUser)
        .where('age').between(20, 40).orderBy('age').findAll();
      expect(mid.length).assertEqual(2);
      expect(mid[0].name).assertEqual('Bob');
      expect(mid[1].name).assertEqual('Carol');

      const likeRes: TestUser[] = await db.from<TestUser>(TestUser)
        .where('name').like('A%').findAll();
      expect(likeRes.length).assertEqual(1);
      expect(likeRes[0].name).assertEqual('Alice');

      const inRes: TestUser[] = await db.from<TestUser>(TestUser)
        .where('email').inList(['alice@x.com', 'dave@x.com']).findAll();
      expect(inRes.length).assertEqual(2);

      const page = await db.from<TestUser>(TestUser).orderBy('age').findPage(1, 2);
      expect(page.total).assertEqual(4);
      expect(page.totalPages).assertEqual(2);
      expect(page.data.length).assertEqual(2);
      expect(page.data[0].name).assertEqual('Alice');
    });

    it('query_or_grouping', 0, async () => {
      await db.rdbStore.executeSql('DELETE FROM users');
      await db.from<TestUser>(TestUser).insertAll([
        makeUser('X', 'x@x.com', 10),
        makeUser('Y', 'y@x.com', 50),
        makeUser('Z', 'z@x.com', 30)
      ]);

      // age < 20 OR age > 40  → X(10), Y(50)
      const res: TestUser[] = await db.from<TestUser>(TestUser)
        .where('age').lt(20)
        .or('age').gt(40)
        .orderBy('age')
        .findAll();
      expect(res.length).assertEqual(2);
      expect(res[0].name).assertEqual('X');
      expect(res[1].name).assertEqual('Y');
    });
  });
}
