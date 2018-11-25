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

#include <cstdint>
#include <memory>
#include <iostream>
#include <vector>
#include <string>
#include <cstring>
#include <numeric>

// Apache Arrow
#include <arrow/api.h>

#include "filter_custom.h"

#define SPECIAL_LAST_NAME "Smith"
#define SPECIAL_LAST_NAME_LENGTH 5

std::shared_ptr<arrow::RecordBatch>
filter_record_batch(std::shared_ptr<arrow::RecordBatch> batch, uint32_t special_zip_code) {
    //Last name to filter on
    const char *special_last_name = SPECIAL_LAST_NAME;

    // Get the StringArray representation of the columns
    auto first_names = std::static_pointer_cast<arrow::StringArray>(batch->column(0));
    auto last_names = std::static_pointer_cast<arrow::StringArray>(batch->column(1));
    auto zip_codes = std::static_pointer_cast<arrow::UInt32Array>(batch->column(2));

    //Buffers for output batch
    std::shared_ptr<arrow::ResizableBuffer> values_buffer;
    std::shared_ptr<arrow::ResizableBuffer> offsets_buffer;
    arrow::AllocateResizableBuffer(last_names->data()->buffers[2]->size(), &values_buffer);
    arrow::AllocateResizableBuffer(last_names->data()->buffers[1]->size(), &offsets_buffer);

    int32_t values_counter = 0;
    int32_t offsets_counter = 0;

    // Set first offset to 0
    std::memset((void *) offsets_buffer->mutable_data(), 0, sizeof(int32_t));

    // Iterate over all rows
    for (int64_t i = 0; i < last_names->length(); i++) {
        // Get the last_name string in a zero-copy manner
        int length;
        const char *str = (const char *) last_names->GetValue(i, &length);
        uint32_t zip_code = zip_codes->Value(i);

        // Only bother comparing the strings if their lengths are equal
        if (length == SPECIAL_LAST_NAME_LENGTH) {
            // If last_name == special_last_name and zip_code == special_zip_code, don't copy first_name
            if (std::memcmp((void *) str, (void *) special_last_name, SPECIAL_LAST_NAME_LENGTH) == 0 &&
                zip_code == special_zip_code) {
                // Copy first name to new batch
                int first_name_length;
                const char *first_name = (const char *) first_names->GetValue(i, &first_name_length);

                std::memcpy((void *) (values_buffer->mutable_data() + values_counter), (void *) first_name,
                            first_name_length);
                values_counter += first_name_length;

                std::memcpy((void *) (offsets_buffer->mutable_data() + offsets_counter + sizeof(int32_t)),
                            (void *) &values_counter,
                            sizeof(int32_t));
                offsets_counter += sizeof(int32_t);
            }
        }
    }

    values_buffer->Resize(values_counter);
    offsets_buffer->Resize(offsets_counter + sizeof(int32_t));

    auto filtered_array = std::make_shared<arrow::StringArray>(offsets_counter/4, offsets_buffer, values_buffer);

    std::vector<std::shared_ptr<arrow::Field>> schema_vector = {
            arrow::field("First", arrow::utf8(), false),
    };
    auto schema = std::make_shared<arrow::Schema>(schema_vector);

    //Create RecordBatch from arrays.
    std::shared_ptr<arrow::RecordBatch> result = arrow::RecordBatch::Make(schema, offsets_counter/4, {filtered_array});

    return result;
}