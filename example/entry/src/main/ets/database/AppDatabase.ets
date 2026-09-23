import { Database } from '@explore-in-hmos/arkorm';
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { User } from '../entity/User';
import { Post } from '../entity/Post';
import { MIGRATION_1_2, MIGRATION_2_3 } from './Migrations';

const DOMAIN: number = 0x0000;

/**
 * The database definition. This class is an *identity marker* only — it is never
 * instantiated. It is opened with `ArkORM.init(context, AppDatabase)` and the
 * live handle is obtained via `ArkORM.getDatabase(AppDatabase)`.
 *
 * Showcases the full set of `@Database` options:
 *  • `securityLevel` — RDB encryption/security level for the store file.
 *  • `migrations`     — manual migrations, run in order before automatic migration.
 *  • `onCreate`       — hook fired once when the DB file is first created.
 *  • `onUpgrade`      — hook fired on every version bump (after migrations run).
 */
@Database({
  entities: [User, Post],
  name: 'arkorm_demo.db',
  version: 3,
  securityLevel: relationalStore.SecurityLevel.S1,
  migrations: [MIGRATION_1_2, MIGRATION_2_3],
  onCreate: async (_store: relationalStore.RdbStore): Promise<void> => {
    hilog.info(DOMAIN, 'ArkORM', 'onCreate: database file created (first run)');
  },
  onUpgrade: async (_store: relationalStore.RdbStore, oldVersion: number, newVersion: number): Promise<void> => {
    hilog.info(DOMAIN, 'ArkORM', `onUpgrade: ${oldVersion} -> ${newVersion}`);
  }
})
export class AppDatabase {}
