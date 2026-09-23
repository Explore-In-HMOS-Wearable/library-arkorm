import {
  Table,
  Column,
  PrimaryKey,
  Unique,
  Index,
  OneToMany,
  TypeConverter,
  DateConverter,
  ColumnType
} from '@explore-in-hmos/arkorm';
import { Post } from './Post';

/**
 * A user of the demo app.
 *
 * Demonstrates: auto-generated primary key, a unique index (declared two ways
 * — `@Unique` on the column AND a named table index), a nullable column, a
 * `Date` field persisted as epoch-millis via the built-in `DateConverter`, and
 * a `@OneToMany` relation back to {@link Post}.
 */
@Table({
  name: 'users',
  indexes: [{ columns: ['email'], unique: true, name: 'idx_users_email' }]
})
export class User {
  @PrimaryKey({ autoGenerate: true })
  @Column({ type: ColumnType.INT })
  id: number = 0;

  // @Index — single-column (non-unique) index on `name` to speed up search.
  @Index()
  @Column({ type: ColumnType.STR })
  name: string = '';

  @Unique()
  @Column({ type: ColumnType.STR })
  email: string = '';

  @Column({ type: ColumnType.INT, nullable: true })
  age: number | null = null;

  // Added in schema v2 — picked up by AUTOMATIC migration (no manual step needed).
  @Column({ type: ColumnType.STR, nullable: true })
  bio: string | null = null;

  @TypeConverter({ converter: new DateConverter() })
  @Column({ type: ColumnType.INT })
  createdAt: Date = new Date(0);

  // Relation field — NOT a column. Filled by `.eager('posts')` or `.load(user, 'posts')`.
  @OneToMany({ targetEntity: () => Post, mappedBy: 'author' })
  posts: Post[] = [];
}
