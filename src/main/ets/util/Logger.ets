import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0xA600;
const TAG: string = 'ArkORM';

/**
 * ArkORM debug logger. Disabled by default; enabled via `ArkORM.setDebugLog(true)`.
 * When enabled, writes executed SQL/DDL and migration steps to hilog.
 */
export class Logger {
  private static enabled: boolean = false;

  static setEnabled(on: boolean): void {
    Logger.enabled = on;
  }

  static isEnabled(): boolean {
    return Logger.enabled;
  }

  static debug(message: string): void {
    if (Logger.enabled) {
      hilog.info(DOMAIN, TAG, '%{public}s', message);
    }
  }

  /** Logs the executed SQL/DDL statement. */
  static sql(statement: string): void {
    if (Logger.enabled) {
      hilog.info(DOMAIN, TAG, '[SQL] %{public}s', statement);
    }
  }

  /** Errors are always logged regardless of the flag. */
  static error(message: string): void {
    hilog.error(DOMAIN, TAG, '%{public}s', message);
  }
}
