import { describe, beforeAll, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';

import { Table } from '../../../main/ets/annotation/Table';
import { Column } from '../../../main/ets/annotation/Column';
import { PrimaryKey } from '../../../main/ets/annotation/PrimaryKey';
import { ForeignKey } from '../../../main/ets/annotation/ForeignKey';
import { OneToMany } from '../../../main/ets/annotation/OneToMany';
import { ManyToOne } from '../../../main/ets/annotation/ManyToOne';
import { Database } from '../../../main/ets/annotation/Database';
import { ArkORM } from '../../../main/ets/core/ArkORM';
import { ArkORMDatabase } from '../../../main/ets/core/ArkORMDatabase';
import { ColumnType } from '../../../main/ets/types/ColumnType';
import { ForeignKeyAction } from '../../../main/ets/types/ForeignKeyAction';

const DB_NAME: string = 'arkorm_rel_test.db';

@Table({ name: 'authors' })
class TestAuthor {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  @Column({ type: ColumnType.STR })
  name: string = '';

  @OneToMany({ targetEntity: () => TestPost, mappedBy: 'author' })
  posts: TestPost[] = [];
}

@Table({ name: 'rel_posts' })
class TestPost {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  @Column({ type: ColumnType.STR })
  title: string = '';

  @ForeignKey({ entity: () => TestAuthor, parentColumn: 'id', childColumn: 'authorId', onDelete: ForeignKeyAction.CASCADE })
  @Column({ type: ColumnType.INT })
  authorId: number = 0;

  @ManyToOne({ targetEntity: () => TestAuthor, joinColumn: 'authorId' })
  author: TestAuthor | null = null;
}

@Database({ entities: [TestAuthor, TestPost], name: DB_NAME, version: 1 })
class TestRelDb {
}

function makePost(title: string, authorId: number): TestPost {
  const p: TestPost = new TestPost();
  p.title = title;
  p.authorId = authorId;
  return p;
}

export default function relationTest() {
  describe('ArkORM_Relations', () => {
    let db: ArkORMDatabase;

    beforeAll(async () => {
      const delegator: abilityDelegatorRegistry.AbilityDelegator =
        abilityDelegatorRegistry.getAbilityDelegator();
      const context: common.Context = delegator.getAppContext() as common.Context;
      await relationalStore.deleteRdbStore(context, DB_NAME);
      await ArkORM.init(context, TestRelDb);
      db = ArkORM.getDatabase(TestRelDb);
    });

    async function reset(): Promise<void> {
      await db.rdbStore.executeSql('DELETE FROM rel_posts');
      await db.rdbStore.executeSql('DELETE FROM authors');
    }

    it('eager_onetomany_and_load_manytoone', 0, async () => {
      await reset();
      const author: TestAuthor = new TestAuthor();
      author.name = 'Ada';
      const aid: number = await db.from<TestAuthor>(TestAuthor).insert(author);
      await db.from<TestPost>(TestPost).insertAll([makePost('P1', aid), makePost('P2', aid)]);

      const withPosts: TestAuthor | null = await db.from<TestAuthor>(TestAuthor)
        .eager('posts').where('id').eq(aid).findOne();
      expect(withPosts !== null).assertTrue();
      expect(withPosts!.posts.length).assertEqual(2);

      const post: TestPost | null = await db.from<TestPost>(TestPost).where('authorId').eq(aid).findOne();
      expect(post !== null).assertTrue();
      await db.from<TestPost>(TestPost).load(post!, 'author');
      expect(post!.author !== null).assertTrue();
      expect(post!.author!.name).assertEqual('Ada');
    });

    it('transaction_commit', 0, async () => {
      await reset();
      await db.transaction(async (tx: ArkORMDatabase): Promise<void> => {
        const a: TestAuthor = new TestAuthor();
        a.name = 'Tx';
        const id: number = await tx.from<TestAuthor>(TestAuthor).insert(a);
        await tx.from<TestPost>(TestPost).insert(makePost('TP', id));
      });
      const authors: number = await db.from<TestAuthor>(TestAuthor).count();
      const posts: number = await db.from<TestPost>(TestPost).count();
      expect(authors).assertEqual(1);
      expect(posts).assertEqual(1);
    });

    it('transaction_rollback', 0, async () => {
      await reset();
      let threw: boolean = false;
      try {
        await db.transaction(async (tx: ArkORMDatabase): Promise<void> => {
          const a: TestAuthor = new TestAuthor();
          a.name = 'Bad';
          await tx.from<TestAuthor>(TestAuthor).insert(a);
          throw new Error('Error');
        });
      } catch (e) {
        threw = true;
      }
      expect(threw).assertTrue();
      const authors: number = await db.from<TestAuthor>(TestAuthor).count();
      expect(authors).assertEqual(0);
    });

    it('cascade_delete', 0, async () => {
      await reset();
      const author: TestAuthor = new TestAuthor();
      author.name = 'Cas';
      const aid: number = await db.from<TestAuthor>(TestAuthor).insert(author);
      await db.from<TestPost>(TestPost).insertAll([makePost('C1', aid), makePost('C2', aid)]);
      expect(await db.from<TestPost>(TestPost).count()).assertEqual(2);

      await db.from<TestAuthor>(TestAuthor).delete(author);
      expect(await db.from<TestPost>(TestPost).count()).assertEqual(0);
    });
  });
}
