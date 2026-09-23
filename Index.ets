// ===== Entity decorators =====
export { Table, TableOptions } from './src/main/ets/annotation/Table';
export { Column, ColumnOptions } from './src/main/ets/annotation/Column';
export { PrimaryKey, PrimaryKeyOptions } from './src/main/ets/annotation/PrimaryKey';
export { Unique } from './src/main/ets/annotation/Unique';
export { Index, IndexOptions } from './src/main/ets/annotation/Index';
export { TypeConverter, TypeConverterOptions } from './src/main/ets/annotation/TypeConverter';
export { ForeignKey, ForeignKeyOptions } from './src/main/ets/annotation/ForeignKey';
export { OneToMany, OneToManyOptions } from './src/main/ets/annotation/OneToMany';
export { ManyToOne, ManyToOneOptions } from './src/main/ets/annotation/ManyToOne';
export { EagerLoad } from './src/main/ets/annotation/EagerLoad';

// ===== Database & DAO decorators =====
export { Database, DatabaseOptions } from './src/main/ets/annotation/Database';

// ===== Core =====
export { ArkORM } from './src/main/ets/core/ArkORM';
export { ArkORMDatabase } from './src/main/ets/core/ArkORMDatabase';
export { MetadataRegistry, metadataRegistry } from './src/main/ets/core/MetadataRegistry';
export { DatabaseMeta } from './src/main/ets/core/DatabaseRegistry';

// ===== DAO =====
export { BaseDao } from './src/main/ets/dao/BaseDao';

// ===== Query (Sprint 3) =====
export { QueryBuilder, Condition } from './src/main/ets/query/QueryBuilder';
export { PageResult } from './src/main/ets/query/PageResult';

// ===== Serializer / converter =====
export { PropertyConverter, DateConverter } from './src/main/ets/serializer/PropertyConverter';
export { EntitySerializer } from './src/main/ets/serializer/EntitySerializer';
export { EntityDeserializer } from './src/main/ets/serializer/EntityDeserializer';

// ===== Relations (Sprint 4) =====
export { RelationLoader } from './src/main/ets/relation/RelationLoader';

// ===== Migration (Sprint 5) =====
export { Migration, MigrationFn } from './src/main/ets/migration/Migration';
export { MigrationEngine } from './src/main/ets/migration/MigrationEngine';
export { SchemaDiff } from './src/main/ets/migration/SchemaDiff';
export { Logger } from './src/main/ets/util/Logger';

// ===== Types =====
export { ColumnType, columnTypeToSqlite } from './src/main/ets/types/ColumnType';
export { OnConflictStrategy } from './src/main/ets/types/OnConflictStrategy';
export { ForeignKeyAction } from './src/main/ets/types/ForeignKeyAction';
export { ColumnMeta, IndexMeta, TableMeta, DefaultValue, TableIndexOption, RelationType, RelationMeta, ForeignKeyMeta } from './src/main/ets/types/Metadata';
