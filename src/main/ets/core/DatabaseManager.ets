import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ArkORMDatabase } from './ArkORMDatabase';
import { DatabaseMeta, databaseRegistry } from './DatabaseRegistry';
import { MigrationEngine } from '../migration/MigrationEngine';
import { AsyncLock } from '../util/AsyncLock';
import { Logger } from '../util/Logger';

/**
 * Singleton holding open database handles. Multi-datasource: multiple
 * `@Database` classes are managed concurrently. Identity = the class itself
 * (`Function`). Schema setup/upgrade is delegated to MigrationEngine.
 */
export class DatabaseManager {
  private handles: Map<Function, ArkORMDatabase> = new Map<Function, ArkORMDatabase>();
  private lock: AsyncLock = new AsyncLock();

  /** Opens the database, sets up the schema on first creation / migrates on upgrade. */
  async init(context: common.Context, databaseClass: Function): Promise<void> {
    await this.lock.runExclusive(async (): Promise<void> => {
      if (this.handles.has(databaseClass)) {
        return;
      }
      const meta: DatabaseMeta = databaseRegistry.get(databaseClass);

      const config: relationalStore.StoreConfig = {
        name: meta.name,
        securityLevel: meta.securityLevel,
        encrypt: meta.encrypt
      };
      if (meta.customDir !== undefined) {
        config.customDir = meta.customDir;
      }

      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
      // Enforce FOREIGN KEY constraints (off by default).
      await store.executeSql('PRAGMA foreign_keys = ON');

      const oldVersion: number = store.version;
      Logger.debug(`'${meta.name}' opened — current v${oldVersion}, target v${meta.version}`);

      if (oldVersion === 0) {
        await MigrationEngine.create(store, meta);
        if (meta.onCreate !== undefined) {
          await meta.onCreate(store);
        }
        store.version = meta.version;
      } else if (oldVersion < meta.version) {
        if (meta.onUpgrade !== undefined) {
          await meta.onUpgrade(store, oldVersion, meta.version);
        }
        await MigrationEngine.migrate(store, meta, oldVersion);
        store.version = meta.version;
      }

      this.handles.set(databaseClass, new ArkORMDatabase(store));
    });
  }

  get(databaseClass: Function): ArkORMDatabase {
    const handle: ArkORMDatabase | undefined = this.handles.get(databaseClass);
    if (handle === undefined) {
      throw new Error(`ArkORM: '${databaseClass.name}' was not initialized. Call ArkORM.init(...) first.`);
    }
    return handle;
  }

  async close(databaseClass: Function): Promise<void> {
    this.handles.delete(databaseClass);
  }
}
