import pyarrow as pa

# Create the string field
string_field = pa.field('String', pa.utf8(), nullable=False)

# Set field metadata
field_meta = {b'fletcher_epc': b'64'}
string_field = string_field.add_metadata(field_meta)

# Create the schema
schema_fields = [string_field]
schema = pa.schema(schema_fields)

# Set schema metadata
schema_meta = {b'fletcher_mode': b'write',
            b'fletcher_name': b'StringWrite'}
schema = schema.add_metadata(schema_meta)

# Serialize schema to file for fletchgen input
serialized_schema = schema.serialize()
pa.output_stream('stringwrite.as').write(serialized_schema)
