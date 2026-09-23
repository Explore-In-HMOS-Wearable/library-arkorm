import { relationalStore } from '@kit.ArkData';
import { metadataRegistry } from '../core/MetadataRegistry';
import { DdlGenerator } from '../core/DdlGenerator';
import { DatabaseMeta } from '../core/DatabaseRegistry';
import { TableMeta } from '../types/Metadata';
import { Migration } from './Migration';
import { SchemaDiff } from './SchemaDiff';
import { Logger } from '../util/Logger';

/**
 * Schema creation and migration orchestration.
 *
 * - `create`: on first setup, creates all tables + indexes.
 * - `migrate`: on upgrade, first runs manual `Migration`s (if any) in order,
 *   then automatic migration (missing table → CREATE, missing column → ALTER ADD).
 * - `destructiveMigration`: drops all tables and recreates them (development).
 */
export class MigrationEngine {
  private static async exec(store: relationalStore.RdbStore, sql: string): Promise<void> {
    Logger.sql(sql);
    await store.executeSql(sql);
  }

  /** First setup: table + index for every entity. */
  static async create(store: relationalStore.RdbStore, meta: DatabaseMeta): Promise<void> {
    for (const entityClass of meta.entities) {
      const tableMeta: TableMeta = metadataRegistry.get(entityClass);
      await MigrationEngine.exec(store, DdlGenerator.buildCreateTable(tableMeta));
      for (const indexSql of DdlGenerator.buildCreateIndexes(tableMeta)) {
        await MigrationEngine.exec(store, indexSql);
      }
    }
  }

  /** Upgrade orchestration. */
  static async migrate(store: relationalStore.RdbStore, meta: DatabaseMeta, oldVersion: number): Promise<void> {
    if (meta.destructiveMigration) {
      Logger.debug(`destructiveMigration → recreating tables (v${oldVersion} → v${meta.version})`);
      await MigrationEngine.dropAll(store, meta);
      await MigrationEngine.create(store, meta);
      return;
    }

    // 1) Run applicable manual migrations in order.
    const applicable: Migration[] = [];
    for (const m of meta.migrations) {
      if (m.fromVersion >= oldVersion && m.toVersion <= meta.version) {
        applicable.push(m);
      }
    }
    applicable.sort((a: Migration, b: Migration): number => a.fromVersion - b.fromVersion);
    for (const m of applicable) {
      Logger.debug(`manual migration v${m.fromVersion} → v${m.toVersion}`);
      await m.migrate(store);
    }

    // 2) Automatic migration: fill in missing tables/columns.
    await MigrationEngine.autoMigrate(store, meta);
  }

  /** Creates missing tables, adds missing columns via ALTER, updates indexes. */
  static async autoMigrate(store: relationalStore.RdbStore, meta: DatabaseMeta): Promise<void> {
    for (const entityClass of meta.entities) {
      const tableMeta: TableMeta = metadataRegistry.get(entityClass);
      const exists: boolean = await SchemaDiff.tableExists(store, tableMeta.tableName);
      if (!exists) {
        await MigrationEngine.exec(store, DdlGenerator.buildCreateTable(tableMeta));
      } else {
        const adds: string[] = await SchemaDiff.missingColumnDdl(store, tableMeta);
        for (const sql of adds) {
          await MigrationEngine.exec(store, sql);
        }
      }
      // Indexes use IF NOT EXISTS, so they are safe to run in all cases.
      for (const indexSql of DdlGenerator.buildCreateIndexes(tableMeta)) {
        await MigrationEngine.exec(store, indexSql);
      }
    }
  }

  /** Drops all entity tables (destructive). */
  static async dropAll(store: relationalStore.RdbStore, meta: DatabaseMeta): Promise<void> {
    for (const entityClass of meta.entities) {
      const tableMeta: TableMeta = metadataRegistry.get(entityClass);
      await MigrationEngine.exec(store, `DROP TABLE IF EXISTS ${tableMeta.tableName}`);
    }
  }
}
