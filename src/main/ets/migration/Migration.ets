import { relationalStore } from '@kit.ArkData';

/** Manual migration body — runs SQL on the raw store. */
export type MigrationFn = (store: relationalStore.RdbStore) => Promise<void>;

/**
 * Manual migration definition. Used for cases requiring data movement that
 * automatic migration cannot handle.
 *
 * ```
 * const MIGRATION_1_2 = new Migration(1, 2, async (store) => {
 *   await store.executeSql('ALTER TABLE users ADD COLUMN bio TEXT');
 * });
 * ```
 */
export class Migration {
  fromVersion: number;
  toVersion: number;
  migrate: MigrationFn;

  constructor(fromVersion: number, toVersion: number, migrate: MigrationFn) {
    this.fromVersion = fromVersion;
    this.toVersion = toVersion;
    this.migrate = migrate;
  }
}
