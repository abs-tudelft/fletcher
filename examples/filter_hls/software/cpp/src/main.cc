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

#include <memory>
#include <arrow/api.h>
#include <iostream>

#include "fletcher/api.h"

#include "person.h"
#include "filter.h"

int main(int argc, char **argv) {

  fletcher::Timer t;

  const std::string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
  const std::string special_last_name = "Smith";
  const zip_t special_zip_code = 1337;
  const uint32_t min_str_len = 3;
  const uint32_t max_str_len = 32;
  const int32_t num_rows = 1024*1024;
  const uint32_t zip_period = 10;
  const uint32_t ln_period = 100;

  // Generate an input dataset
  t.start();
  auto dataset_in_vec = generateInput(special_last_name,
                                   special_zip_code,
                                   alphabet,
                                   min_str_len,
                                   max_str_len,
                                   num_rows,
                                   ln_period,
                                   zip_period,
                                   false);
  t.stop();
  std::cout << "Generate: " << t.seconds() << std::endl;

  t.start();
  auto dataset_in_rb = serialize(dataset_in_vec);
  t.stop();
  std::cout << "Serialize: " << t.seconds() << std::endl;

  t.start();
  auto dataset_out_vec = filterVec(dataset_in_vec, special_last_name, special_zip_code);
  t.stop();
  std::cout << "Vector<Person> -> Vector<LastName> (CPU)          : " << t.seconds() << std::endl;

  t.start();
  auto dataset_out_arr = filterArrow(dataset_in_rb, special_last_name, special_zip_code);
  t.stop();
  std::cout << "RecordBatch<Person> -> StringArray<LastName> (CPU): " << t.seconds() << std::endl;

  size_t max_out_bytes = dataset_out_vec->size() * max_str_len;

  auto dataset_out_fpga = getOutputRB(dataset_out_vec->size(), max_out_bytes);


  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;
  std::shared_ptr<fletcher::UserCore> uc;

  fletcher::Platform::Make(&platform);

  platform->init();

  fletcher::Context::Make(&context, platform);

  uc = std::make_shared<fletcher::UserCore>(context);

  context->queueRecordBatch(dataset_in_rb);
  context->queueRecordBatch(dataset_out_fpga);

  uc->reset();

  context->enable();

  uc->setRange(0, num_rows);
  //uc->setArguments({1337}); // zip code

  uc->start();

  uc->waitForFinish(10);

  // Get raw pointers to host-side Arrow buffers
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(dataset_out_fpga->column(0));

  auto raw_offsets = sa->value_offsets()->mutable_data();
  auto raw_values = sa->value_data()->mutable_data();

  platform->copyDeviceToHost(context->device_arrays[3]->buffers[0].device_address,
                             raw_offsets,
                             sa->value_offsets()->size());
  platform->copyDeviceToHost(context->device_arrays[3]->buffers[1].device_address,
                             raw_values,
                             sa->value_data()->size());

  fletcher::HexView hvo((uint64_t) raw_offsets);
  hvo.addData(raw_offsets, sizeof(int32_t) * (num_rows + 1));
  fletcher::HexView hvv((uint64_t) raw_values);
  hvv.addData(raw_values, 10);

  std::cout << hvo.toString() << std::endl;
  std::cout << hvv.toString() << std::endl;

  return 0;
}
