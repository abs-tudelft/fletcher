import pyarrow as pa

# Input schema and batch
in_schema = pa.schema([pa.field('number', pa.int64(), nullable=False)])
in_schema = in_schema.with_metadata({b'fletcher_mode': b'read',
                                     b'fletcher_name': b'in'})
in_data = [pa.array([1, -3, 3, -7])]
in_batch = pa.RecordBatch.from_arrays(in_data, schema=in_schema)
# Create an Arrow RecordBatchFileWriter.
writer = pa.RecordBatchFileWriter('in.rb', in_schema)
writer.write(in_batch)
writer.close()

# Output schema and batch
out_schema = pa.schema([pa.field('number', pa.int64(), nullable=False)])
out_schema = out_schema.with_metadata({b'fletcher_mode': b'write',
                                       b'fletcher_name': b'out'})
pa.output_stream('out.as').write(out_schema.serialize())
