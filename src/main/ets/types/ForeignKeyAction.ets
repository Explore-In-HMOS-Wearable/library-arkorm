/**
 * Delete/update behavior for `@ForeignKey` (SQLite `ON DELETE`).
 */
export enum ForeignKeyAction {
  NO_ACTION,
  RESTRICT,
  CASCADE,
  SET_NULL
}

/** ForeignKeyAction → SQLite DDL clause. */
export function foreignKeyActionToSql(action: ForeignKeyAction): string {
  switch (action) {
    case ForeignKeyAction.RESTRICT:
      return 'RESTRICT';
    case ForeignKeyAction.CASCADE:
      return 'CASCADE';
    case ForeignKeyAction.SET_NULL:
      return 'SET NULL';
    case ForeignKeyAction.NO_ACTION:
    default:
      return 'NO ACTION';
  }
}
