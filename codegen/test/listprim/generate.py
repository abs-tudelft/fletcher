import pyarrow as pa

# Create a field that can be interpreted as a "listprim" ArrayReader/Writer
vec_field = pa.field('vec', pa.list_(pa.field('elem', pa.int16(), nullable=False)), nullable=False)

schema_src = pa.schema([vec_field]).with_metadata({b'fletcher_mode': b'read', b'fletcher_name': b'src'})
schema_dst = pa.schema([vec_field]).with_metadata({b'fletcher_mode': b'write', b'fletcher_name': b'dst'})

data = [pa.array([[1, -3, 3, -7], [4, 5, 10]])]

recordbatch = pa.RecordBatch.from_arrays(data, schema=schema_src)
writer_in = pa.RecordBatchFileWriter('src.rb', schema_src)
writer_in.write(recordbatch)
writer_in.close()

serialized_out_schema = schema_dst.serialize()
pa.output_stream('dst.as').write(serialized_out_schema)
