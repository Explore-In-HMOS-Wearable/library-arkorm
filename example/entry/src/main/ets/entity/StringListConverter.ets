import { PropertyConverter } from '@explore-in-hmos/arkorm';
import { relationalStore } from '@kit.ArkData';

/**
 * Custom `@TypeConverter` — `string[]` ⇄ JSON TEXT.
 *
 * Demonstrates the converter extension point (ArkORM only ships `DateConverter`
 * out of the box). The base `PropertyConverter` is deliberately non-generic in
 * ArkTS, so we cast with `as` on both sides.
 */
export class StringListConverter extends PropertyConverter {
  convertToEntityProperty(dbValue: relationalStore.ValueType): Object {
    const raw: string = dbValue as string;
    if (raw.length === 0) {
      return [] as string[];
    }
    return JSON.parse(raw) as string[];
  }

  convertToDatabaseValue(value: Object): relationalStore.ValueType {
    return JSON.stringify(value as string[]);
  }
}
