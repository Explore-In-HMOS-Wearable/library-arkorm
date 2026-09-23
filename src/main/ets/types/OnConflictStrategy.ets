import { relationalStore } from '@kit.ArkData';

/**
 * Strategy applied when a constraint is violated during insert/update.
 * Corresponds to SQLite's `ON CONFLICT` behaviors.
 */
export enum OnConflictStrategy {
  NONE,
  ROLLBACK,
  ABORT,
  FAIL,
  IGNORE,
  REPLACE
}

/** Converts the ArkORM strategy to a RelationalStore `ConflictResolution`. */
export function toConflictResolution(strategy: OnConflictStrategy): relationalStore.ConflictResolution {
  switch (strategy) {
    case OnConflictStrategy.ROLLBACK:
      return relationalStore.ConflictResolution.ON_CONFLICT_ROLLBACK;
    case OnConflictStrategy.ABORT:
      return relationalStore.ConflictResolution.ON_CONFLICT_ABORT;
    case OnConflictStrategy.FAIL:
      return relationalStore.ConflictResolution.ON_CONFLICT_FAIL;
    case OnConflictStrategy.IGNORE:
      return relationalStore.ConflictResolution.ON_CONFLICT_IGNORE;
    case OnConflictStrategy.REPLACE:
      return relationalStore.ConflictResolution.ON_CONFLICT_REPLACE;
    case OnConflictStrategy.NONE:
    default:
      return relationalStore.ConflictResolution.ON_CONFLICT_NONE;
  }
}
