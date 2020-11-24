import pyarrow as pa

list_type = pa.list_(pa.field('item', pa.uint8(), nullable=False), 3)
field = pa.field('foo', list_type, nullable=False)

schema_src = pa.schema([field]).with_metadata({b'fletcher_mode': b'read', b'fletcher_name': b'src'})
schema_dst = pa.schema([field]).with_metadata({b'fletcher_mode': b'write', b'fletcher_name': b'dst'})

data = [pa.array([[0, 1, 2], [3, 4, 5]], list_type)]

recordbatch = pa.RecordBatch.from_arrays(data, schema=schema_src)
writer_in = pa.RecordBatchFileWriter('src.rb', schema_src)
writer_in.write(recordbatch)
writer_in.close()

serialized_out_schema = schema_dst.serialize()
pa.output_stream('dst.as').write(serialized_out_schema)
