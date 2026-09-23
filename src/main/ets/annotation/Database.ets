import { relationalStore } from '@kit.ArkData';
import { DatabaseMeta, databaseRegistry, OnCreateHook, OnUpgradeHook } from '../core/DatabaseRegistry';
import { Migration } from '../migration/Migration';

export interface DatabaseOptions {
  entities: Function[];
  name: string;
  version: number;
  securityLevel?: relationalStore.SecurityLevel;
  encrypt?: boolean;
  customDir?: string;
  destructiveMigration?: boolean;
  migrations?: Migration[];
  /** Called once on first creation (callback instead of method override). */
  onCreate?: OnCreateHook;
  /** Called on version upgrade. */
  onUpgrade?: OnUpgradeHook;
}

/**
 * `@Database({ entities, name, version, ... })` — marks a class as a database
 * definition (identity marker). The class is not instantiated; it is opened
 * via `ArkORM.init(context, AppDatabase)`.
 */
export function Database(options: DatabaseOptions): (target: Function) => void {
  return (target: Function): void => {
    const securityLevel: relationalStore.SecurityLevel =
      options.securityLevel !== undefined ? options.securityLevel : relationalStore.SecurityLevel.S1;
    const encrypt: boolean = options.encrypt !== undefined ? options.encrypt : false;
    const destructive: boolean = options.destructiveMigration !== undefined ? options.destructiveMigration : false;
    const migrations: Migration[] = options.migrations !== undefined ? options.migrations : [];

    databaseRegistry.register(target, new DatabaseMeta(
      target, options.entities, options.name, options.version,
      securityLevel, encrypt, options.customDir, destructive, migrations,
      options.onCreate, options.onUpgrade
    ));
  };
}
