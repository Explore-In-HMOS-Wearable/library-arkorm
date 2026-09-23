import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ArkORM, ArkORMDatabase, PageResult, OnConflictStrategy } from '@explore-in-hmos/arkorm';
import { AppDatabase } from './AppDatabase';
import { User } from '../entity/User';
import { Post } from '../entity/Post';

/**
 * Thin service wrapper around ArkORM so the UI never touches the ORM directly.
 * Every method here showcases a different ArkORM capability.
 */
export class DbService {
  private static db: ArkORMDatabase | null = null;

  /** Opens the database once. Safe to call repeatedly (init is a no-op when open). */
  static async init(context: common.Context): Promise<void> {
    if (DbService.db !== null) {
      return;
    }
    ArkORM.setDebugLog(true);               // logs executed SQL/DDL to hilog
    await ArkORM.init(context, AppDatabase);
    DbService.db = ArkORM.getDatabase(AppDatabase);
  }

  private static get(): ArkORMDatabase {
    if (DbService.db === null) {
      throw new Error('DbService.init() must be awaited before use');
    }
    return DbService.db;
  }

  // ---- Create -------------------------------------------------------------

  /**
   * Inserts a user. Demonstrates `exists()` as a pre-check (return -1 on a
   * duplicate email so the UI can warn) and an explicit `OnConflictStrategy`
   * on `insert` (ABORT here; IGNORE/REPLACE are the other options). The
   * auto-generated id is written back onto the entity.
   */
  static async addUser(name: string, email: string, age: number | null, bio: string | null): Promise<number> {
    const db = DbService.get();
    const duplicate: boolean = await db.from<User>(User).where('email').eq(email).exists();
    if (duplicate) {
      return -1;
    }
    const user = new User();
    user.name = name;
    user.email = email;
    user.age = age;
    user.bio = bio;            // v2 column
    user.createdAt = new Date();
    return await db.from<User>(User).insert(user, OnConflictStrategy.ABORT);
  }

  /** Inserts a post for an existing user (with v2 `published` + v3 `tags`). */
  static async addPost(authorId: number, title: string, body: string, published: boolean, tags: string[]): Promise<number> {
    const post = new Post();
    post.authorId = authorId;
    post.title = title;
    post.body = body;
    post.published = published; // v2 column
    post.tags = tags;           // v3 column (custom JSON converter)
    return await DbService.get().from<Post>(Post).insert(post);
  }

  /**
   * Batch-seeds a handful of famous engineers using `OnConflictStrategy.IGNORE`
   * so re-running is idempotent — the fixed emails hit the unique index on the
   * second press and are silently skipped. Returns how many were actually added.
   */
  static async seedManyUsers(): Promise<number> {
    const db = DbService.get();
    const names: string[] = ['Grace Hopper', 'Linus Torvalds', 'Margaret Hamilton', 'Dennis Ritchie', 'Barbara Liskov'];
    let inserted: number = 0;
    for (let i = 0; i < names.length; i++) {
      const u = new User();
      u.name = names[i];
      u.email = `bulk-${i}@example.com`;     // fixed → conflicts on re-run
      u.age = 30 + i;
      u.createdAt = new Date();
      const rowId: number = await db.from<User>(User).insert(u, OnConflictStrategy.IGNORE);
      if (rowId > 0) {
        inserted++;
      }
    }
    return inserted;
  }

  // ---- Read ---------------------------------------------------------------

  /** All users, newest first. */
  static async listUsers(): Promise<User[]> {
    return await DbService.get().from<User>(User).orderBy('id', true).findAll();
  }

  /** Fluent query: adults (age >= 18) that also have an email, sorted by name. */
  static async listAdults(): Promise<User[]> {
    return await DbService.get().from<User>(User)
      .where('age').gte(18)
      .and('email').isNotNull()
      .orderBy('name')
      .findAll();
  }

  /**
   * Fluent query over the v2 `published` flag: every published post, newest
   * first. The author is filled automatically thanks to `@EagerLoad` on
   * `Post.author` — no `.eager('author')` needed. ArkORM stores `BOOL` as 0/1
   * and binds `true` as 1, so `.where('published').eq(true)` matches.
   */
  static async listPublishedPosts(): Promise<Post[]> {
    return await DbService.get().from<Post>(Post)
      .where('published').eq(true)
      .orderBy('id', true)
      .findAll();
  }

  /**
   * Full-text-ish search across name OR email. Demonstrates the `like` operator
   * and `or` grouping in the fluent builder.
   */
  static async searchUsers(term: string): Promise<User[]> {
    const pattern: string = `%${term}%`;
    return await DbService.get().from<User>(User)
      .where('name').like(pattern)
      .or('email').like(pattern)
      .orderBy('name')
      .findAll();
  }

  /** EAGER load: pulls a user and their posts in one query (`.eager('posts')`). */
  static async getUserWithPosts(userId: number): Promise<User | null> {
    return await DbService.get().from<User>(User)
      .eager('posts')
      .where('id').eq(userId)
      .findOne();
  }

  /**
   * LAZY load: fetch the user first, then explicitly populate the relation with
   * `.load(user, 'posts')`. ArkTS has no `Proxy`, so lazy loading is an explicit
   * call rather than property-access magic.
   */
  static async getUserWithPostsLazy(userId: number): Promise<User | null> {
    const db = DbService.get();
    const user: User | null = await db.from<User>(User).where('id').eq(userId).findOne();
    if (user === null) {
      return null;
    }
    await db.from<User>(User).load(user, 'posts');
    return user;
  }

  static async countUsers(): Promise<number> {
    return await DbService.get().from<User>(User).count();
  }

  /**
   * Builds a one-line stats string, exercising three escape hatches at once:
   *  • `rawResultSet` — a manual aggregate over a raw `ResultSet` (caller closes).
   *  • `rawQuery<User>` — raw SQL mapped straight back to typed entities.
   *  • `findPage` / `PageResult` — pagination metadata (total pages).
   */
  static async statsReport(): Promise<string> {
    const db = DbService.get();

    const rs: relationalStore.ResultSet =
      await db.rawResultSet('SELECT COUNT(*) AS c FROM posts WHERE published = 1', []);
    let publishedPosts: number = 0;
    if (rs.goToFirstRow()) {
      publishedPosts = rs.getLong(rs.getColumnIndex('c'));
    }
    rs.close();

    const seniors: User[] =
      await db.rawQuery<User>('SELECT * FROM users WHERE age >= ? ORDER BY age DESC', [40], User);

    const page: PageResult<User> = await db.from<User>(User).orderBy('id').findPage(1, 3);

    return `published posts: ${publishedPosts} · age 40+: ${seniors.length} · pages@3: ${page.totalPages}`;
  }

  // ---- Update -------------------------------------------------------------

  /** Flips a post's v2 `published` flag and persists it (update by PK). */
  static async setPostPublished(post: Post, published: boolean): Promise<number> {
    post.published = published;
    return await DbService.get().from<Post>(Post).update(post);
  }

  /** Loads a user by PK, mutates a field, and persists with `update`. */
  static async renameUser(userId: number, newName: string): Promise<number> {
    const db = DbService.get();
    const user = await db.from<User>(User).where('id').eq(userId).findOne();
    if (user === null) {
      return 0;
    }
    user.name = newName;
    return await db.from<User>(User).update(user);
  }

  // ---- Delete -------------------------------------------------------------

  /** Deletes a user by PK; CASCADE removes their posts automatically. */
  static async deleteUser(user: User): Promise<number> {
    return await DbService.get().from<User>(User).delete(user);
  }

  /** Wipes everything (delete via the query builder, no entity needed). */
  static async clearAll(): Promise<void> {
    const db = DbService.get();
    await db.from<Post>(Post).query().delete();
    await db.from<User>(User).query().delete();
  }

  // ---- Lifecycle ----------------------------------------------------------

  /** Closes the store handle (does NOT delete the file). `init()` re-opens it. */
  static async close(): Promise<void> {
    if (DbService.db === null) {
      return;
    }
    await ArkORM.close(AppDatabase);
    DbService.db = null;
  }

  // ---- Transaction --------------------------------------------------------

  /**
   * Seeds demo data inside a single transaction. If anything throws, the whole
   * batch is rolled back — you never end up with a half-written graph.
   */
  static async seedDemo(): Promise<void> {
    const db = DbService.get();
    await db.transaction(async (tx: ArkORMDatabase): Promise<void> => {
      const ada = new User();
      ada.name = 'Ada Lovelace';
      ada.email = `ada${Date.now()}@example.com`;
      ada.age = 28;
      ada.bio = 'First programmer.';
      ada.createdAt = new Date();
      const adaId = await tx.from<User>(User).insert(ada);

      const alan = new User();
      alan.name = 'Alan Turing';
      alan.email = `alan${Date.now()}@example.com`;
      alan.age = 41;
      alan.bio = 'Father of computer science.';
      alan.createdAt = new Date();
      const alanId = await tx.from<User>(User).insert(alan);

      const p1 = new Post();
      p1.authorId = adaId;
      p1.title = 'On the Analytical Engine';
      p1.body = 'Notes on the first algorithm.';
      p1.published = true;
      p1.tags = ['history', 'computing'];

      const p2 = new Post();
      p2.authorId = alanId;
      p2.title = 'Computing Machinery and Intelligence';
      p2.body = 'Can machines think?';
      p2.published = false;       // a draft, to show the v2 `published` flag
      p2.tags = ['ai', 'philosophy'];

      // Batch insert — both posts in one call (sliced by pageSize internally).
      await tx.from<Post>(Post).insertAll([p1, p2]);
    });
  }
}
