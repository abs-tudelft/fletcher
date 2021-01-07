import pyarrow as pa

# Create a field that can be interpreted as a "listprim" ArrayReader/Writer
input_schema = pa.schema([pa.field('A', pa.int8(), nullable=False),
                          pa.field('B', pa.int8(), nullable=False)])
input_schema = input_schema.with_metadata({b'fletcher_mode': b'read', b'fletcher_name': b'R'})

output_schema = pa.schema([pa.field('C', pa.int8(), nullable=False),
                           pa.field('D', pa.int8(), nullable=False)])
output_schema = output_schema.with_metadata({b'fletcher_mode': b'write', b'fletcher_name': b'W'})

batch_data = [pa.array([1, -3, 3, -7], pa.int8()),
              pa.array([4, 2, -6, -9], pa.int8())]

input_batch = pa.RecordBatch.from_arrays(batch_data, schema=input_schema)
writer_in = pa.RecordBatchFileWriter('in.rb', input_schema)
writer_in.write(input_batch)
writer_in.close()

serialized_out_schema = output_schema.serialize()
pa.output_stream('out.as').write(serialized_out_schema)
