// Copyright 2018 Delft University of Technology
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/**
 * Generate schema flatbuffer for sum example
 */
#include <vector>
#include <iostream>

// Apache Arrow
#include <arrow/api.h>
#include <arrow/io/api.h>
#include <arrow/ipc/api.h>
#include <arrow/buffer.h>

int main()
{
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
    arrow::field(
      "point", arrow::list(
        arrow::field(
          "dimension",
          arrow::float64(),
          false, // non-nullable
          std::make_shared<arrow::KeyValueMetadata>(
            std::vector<std::string> {"epc"},
            std::vector<std::string> {std::to_string(512/64)}
          )
        ) // end dimension field
      ), // end list datatype
      false // non-nullable
    ) // end point field
  };

  // Create the schema
  auto schema = std::make_shared<arrow::Schema>(schema_fields);

  // Create buffer to store the serialized schema in:
  std::shared_ptr<arrow::ResizableBuffer> buffer;
  arrow::AllocateResizableBuffer(
    arrow::default_memory_pool(),
    0,
    &buffer
  );

  // Serialize the schema into the buffer:
  arrow::ipc::SerializeSchema(
    *schema,
    arrow::default_memory_pool(),
    reinterpret_cast<std::shared_ptr<arrow::Buffer>*>(&buffer)
  );

  // Write the buffer to a file:
  std::shared_ptr<arrow::io::FileOutputStream> fos;
  if (arrow::io::FileOutputStream::Open("numberlist.fbs", &fos).ok()) {
    fos->Write(buffer->data(), buffer->size());
  } else {
    throw std::runtime_error(
      "Could not open schema file for writing: numberlist.fbs");
  }

  return EXIT_SUCCESS;
}

