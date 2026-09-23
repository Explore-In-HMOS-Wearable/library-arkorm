import {
  Table,
  Column,
  PrimaryKey,
  ForeignKey,
  ManyToOne,
  EagerLoad,
  TypeConverter,
  ColumnType,
  ForeignKeyAction
} from '@explore-in-hmos/arkorm';
import { User } from './User';
import { StringListConverter } from './StringListConverter';

/**
 * A post authored by a {@link User}.
 *
 * Demonstrates: a `@ForeignKey` with `ON DELETE CASCADE` (deleting a user wipes
 * their posts automatically) and a `@ManyToOne` relation that resolves the
 * author. The relation uses a `() => User` thunk so the circular import between
 * User and Post resolves cleanly in ArkTS strict mode.
 */
@Table({ name: 'posts' })
export class Post {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  @Column({ type: ColumnType.STR })
  title: string = '';

  @Column({ type: ColumnType.STR })
  body: string = '';

  // Added in schema v2 — back-filled to `true` for existing rows by MIGRATION_1_2.
  // `defaultValue` puts `DEFAULT 1` in the generated DDL for fresh installs.
  @Column({ type: ColumnType.BOOL, defaultValue: true })
  published: boolean = true;

  // Added in schema v3 — `string[]` stored as JSON TEXT via a custom converter.
  @TypeConverter({ converter: new StringListConverter() })
  @Column({ type: ColumnType.STR, defaultValue: '[]' })
  tags: string[] = [];

  @ForeignKey({
    entity: () => User,
    parentColumn: 'id',
    childColumn: 'authorId',
    onDelete: ForeignKeyAction.CASCADE
  })
  @Column({ type: ColumnType.INT })
  authorId: number = 0;

  // Relation field — NOT a column. The FK value lives in `authorId`.
  // @EagerLoad forces the author to be loaded on EVERY post query, so callers
  // don't have to chain `.eager('author')` themselves.
  @EagerLoad
  @ManyToOne({ targetEntity: () => User, joinColumn: 'authorId' })
  author: User | null = null;
}
