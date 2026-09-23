import { Migration } from '@explore-in-hmos/arkorm';
import { relationalStore } from '@kit.ArkData';

/**
 * v1 → v2 schema bump.
 *
 * Two columns are introduced in v2:
 *   • `User.bio`       — left to AUTOMATIC migration. ArkORM diffs the schema via
 *     `PRAGMA table_info` and issues `ALTER TABLE users ADD COLUMN bio` on its own;
 *     no entry is needed here.
 *   • `Post.published` — handled MANUALLY below, because we want every *existing*
 *     post to be treated as published (`DEFAULT 1`). Automatic add-column can
 *     create the column but can't express that data intent, so we do it ourselves.
 *
 * Order matters: ArkORM runs manual `Migration`s FIRST, then automatic migration
 * fills any remaining gaps. So we both ADD the column and back-fill it in one
 * statement here; auto-migration then sees `published` already exists and skips it,
 * while still adding `bio`.
 *
 * Note: on a *fresh* v2 install the tables are created directly from the current
 * metadata (migrations don't run), so both columns exist either way.
 */
export const MIGRATION_1_2: Migration = new Migration(1, 2,
  async (store: relationalStore.RdbStore): Promise<void> => {
    await store.executeSql('ALTER TABLE posts ADD COLUMN published INTEGER NOT NULL DEFAULT 1');
  });

/**
 * v2 → v3 schema bump. Adds `Post.tags` (a `string[]` persisted as JSON TEXT via
 * the custom {@link StringListConverter}). Existing rows are back-filled to an
 * empty JSON array so the converter always reads valid JSON.
 *
 * Migrations are applied in order, so the `migrations` list below chains
 * 1→2 then 2→3 when upgrading straight from a v1 database.
 */
export const MIGRATION_2_3: Migration = new Migration(2, 3,
  async (store: relationalStore.RdbStore): Promise<void> => {
    await store.executeSql("ALTER TABLE posts ADD COLUMN tags TEXT NOT NULL DEFAULT '[]'");
  });
