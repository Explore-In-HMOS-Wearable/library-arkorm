import { relationalStore } from '@kit.ArkData';
import { Migration } from '../migration/Migration';

export type OnCreateHook = (store: relationalStore.RdbStore) => Promise<void>;
export type OnUpgradeHook = (store: relationalStore.RdbStore, oldVersion: number, newVersion: number) => Promise<void>;

/**
 * Metadata of a database class defined with `@Database`.
 * `migrations` will be processed in Sprint 5; stored now for forward-compat.
 */
export class DatabaseMeta {
  databaseClass: Function;
  entities: Function[];
  name: string;
  version: number;
  securityLevel: relationalStore.SecurityLevel;
  encrypt: boolean;
  customDir: string | undefined;
  destructiveMigration: boolean;
  migrations: Migration[];
  onCreate: OnCreateHook | undefined;
  onUpgrade: OnUpgradeHook | undefined;

  constructor(databaseClass: Function, entities: Function[], name: string, version: number,
    securityLevel: relationalStore.SecurityLevel, encrypt: boolean,
    customDir: string | undefined, destructiveMigration: boolean, migrations: Migration[],
    onCreate: OnCreateHook | undefined, onUpgrade: OnUpgradeHook | undefined) {
    this.databaseClass = databaseClass;
    this.entities = entities;
    this.name = name;
    this.version = version;
    this.securityLevel = securityLevel;
    this.encrypt = encrypt;
    this.customDir = customDir;
    this.destructiveMigration = destructiveMigration;
    this.migrations = migrations;
    this.onCreate = onCreate;
    this.onUpgrade = onUpgrade;
  }
}

/**
 * Registry holding `@Database` metadata keyed by the database class ITSELF
 * (Function). The class can be used as a value in the form of a `Function` key
 * (e.g. `entities: [User]`), which is allowed in ArkTS — so no instance/prototype
 * is needed.
 */
export class DatabaseRegistry {
  private databases: Map<Function, DatabaseMeta> = new Map<Function, DatabaseMeta>();

  register(databaseClass: Function, meta: DatabaseMeta): void {
    this.databases.set(databaseClass, meta);
  }

  get(databaseClass: Function): DatabaseMeta {
    const meta: DatabaseMeta | undefined = this.databases.get(databaseClass);
    if (meta === undefined) {
      throw new Error(`ArkORM: no @Database metadata for '${databaseClass.name}'.`);
    }
    return meta;
  }

  has(databaseClass: Function): boolean {
    return this.databases.has(databaseClass);
  }

  clear(): void {
    this.databases.clear();
  }
}

export const databaseRegistry: DatabaseRegistry = new DatabaseRegistry();
