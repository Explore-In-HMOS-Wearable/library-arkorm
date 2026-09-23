import { common } from '@kit.AbilityKit';
import { ArkORMDatabase } from './ArkORMDatabase';
import { DatabaseManager } from './DatabaseManager';
import { Logger } from '../util/Logger';

/**
 * Main entry point of ArkORM. Manages the database lifecycle.
 *
 * The `@Database` class is passed purely as an identity marker (never
 * instantiated):
 *
 * ```
 * await ArkORM.init(context, AppDatabase);
 * const db = ArkORM.getDatabase(AppDatabase);
 * const id = await db.from<User>(User).insert(user);
 * await ArkORM.close(AppDatabase);
 * ```
 */
export class ArkORM {
  private static manager: DatabaseManager = new DatabaseManager();

  /** Enables/disables debug logging (executed SQL/DDL + migration steps). */
  static setDebugLog(enabled: boolean): void {
    Logger.setEnabled(enabled);
  }

  /** Opens the database and sets up the schema (if needed). A repeat call is a no-op. */
  static async init(context: common.Context, databaseClass: Function): Promise<void> {
    await ArkORM.manager.init(context, databaseClass);
  }

  /** Returns the opened database handle. */
  static getDatabase(databaseClass: Function): ArkORMDatabase {
    return ArkORM.manager.get(databaseClass);
  }

  /** Closes the database handle (does not delete the file). */
  static async close(databaseClass: Function): Promise<void> {
    await ArkORM.manager.close(databaseClass);
  }
}
