import { relationalStore } from '@kit.ArkData';

/**
 * Base class for converting between an entity property type and a database value.
 *
 * Because of ArkTS generic variance constraints (assigning a
 * PropertyConverter<Date> where a PropertyConverter<Object> is expected breaks
 * the nominal type system), the base class is deliberately NON-generic: the db
 * side is `relationalStore.ValueType`, the entity side is `Object`. Subclasses
 * cast to the concrete type with `as` inside their bodies.
 */
export abstract class PropertyConverter {
  /** Converts a value read from the DB into the entity property. */
  abstract convertToEntityProperty(dbValue: relationalStore.ValueType): Object;

  /** Converts an entity property into the value to be written to the DB. */
  abstract convertToDatabaseValue(value: Object): relationalStore.ValueType;
}

/**
 * Built-in converter: `Date` ↔ epoch-millis (stored as INTEGER).
 * Used via `@TypeConverter({ converter: DateConverter })`.
 */
export class DateConverter extends PropertyConverter {
  convertToEntityProperty(dbValue: relationalStore.ValueType): Object {
    // Stored as INT → getLong returns a number.
    return new Date(dbValue as number);
  }

  convertToDatabaseValue(value: Object): relationalStore.ValueType {
    return (value as Date).getTime();
  }
}
