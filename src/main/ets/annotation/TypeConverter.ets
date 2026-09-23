import { metadataRegistry } from '../core/MetadataRegistry';
import { ColumnMeta } from '../types/Metadata';
import { PropertyConverter } from '../serializer/PropertyConverter';

export interface TypeConverterOptions {
  /**
   * Converter INSTANCE (not the class). Because ArkTS does not allow
   * constructor-type signatures (`new () => T`), an instance is taken instead of a class:
   * `@TypeConverter({ converter: new DateConverter() })`.
   */
  converter: PropertyConverter;
}

/**
 * `@TypeConverter({ converter })` — custom type conversion for a property.
 * The converter is written to ColumnMeta to be used by the serializer/deserializer.
 */
export function TypeConverter(options: TypeConverterOptions): (target: Object, propertyKey: string) => void {
  return (target: Object, propertyKey: string): void => {
    const col: ColumnMeta = metadataRegistry.getOrCreateColumn(target, propertyKey);
    col.converter = options.converter;
  };
}
