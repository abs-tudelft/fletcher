// Copyright 2018-2019 Delft University of Technology
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

#include <gtest/gtest.h>
#include <arrow/api.h>
#include <arrow/ipc/api.h>
#include <arrow/io/api.h>
#include <fletcher/test_recordbatches.h>

#include <vector>
#include <memory>
#include <fstream>

#include "fletchgen/srec/srec.h"
#include "fletchgen/srec/recordbatch.h"

namespace fletchgen::srec {

/*
 * SREC example from Linux man page srec(5):
 *
 * S00600004844521B
 * S1130000285F245F2212226A000424290008237C2A
 * S11300100002000800082629001853812341001813
 * S113002041E900084E42234300182342000824A952
 * S107003000144ED492
 */

TEST(SREC, ToString) {
  uint8_t data0[16] = {0x28, 0x5F, 0x24, 0x5F, 0x22, 0x12, 0x22, 0x6A, 0x00, 0x04, 0x24, 0x29, 0x00, 0x08, 0x23, 0x7C};
  uint8_t data1[16] = {0x00, 0x02, 0x00, 0x08, 0x00, 0x08, 0x26, 0x29, 0x00, 0x18, 0x53, 0x81, 0x23, 0x41, 0x00, 0x18};
  uint8_t data2[16] = {0x41, 0xE9, 0x00, 0x08, 0x4E, 0x42, 0x23, 0x43, 0x00, 0x18, 0x23, 0x42, 0x00, 0x08, 0x24, 0xA9};
  uint8_t data3[4] = {0x00, 0x14, 0x4E, 0xD4};
  // Check header record. Default header is similar to example.
  ASSERT_EQ(Record::Header().ToString(), "S00600004844521B");
  // Check other records
  ASSERT_EQ(Record::Data<16>(0x00, data0, 16).ToString(), "S1130000285F245F2212226A000424290008237C2A");
  ASSERT_EQ(Record::Data<16>(0x10, data1, 16).ToString(), "S11300100002000800082629001853812341001813");
  ASSERT_EQ(Record::Data<16>(0x20, data2, 16).ToString(), "S113002041E900084E42234300182342000824A952");
  ASSERT_EQ(Record::Data<16>(0x30, data3, 4).ToString(), "S107003000144ED492");
}

#define TEST_SREC_STR(X) ASSERT_EQ((*Record::FromString(X)).ToString(), X)

TEST(SREC, FromString) {
  // Test a round trip
  TEST_SREC_STR("S00600004844521B");
  TEST_SREC_STR("S1130000285F245F2212226A000424290008237C2A");
  TEST_SREC_STR("S11300100002000800082629001853812341001813");
  TEST_SREC_STR("S113002041E900084E42234300182342000824A952");
  TEST_SREC_STR("S107003000144ED492");
}

TEST(SREC, File) {
  // Test a round trip via a file.
  uint8_t data[52] = {0x28, 0x5F, 0x24, 0x5F, 0x22, 0x12, 0x22, 0x6A, 0x00, 0x04, 0x24, 0x29, 0x00, 0x08, 0x23, 0x7C,
                      0x00, 0x02, 0x00, 0x08, 0x00, 0x08, 0x26, 0x29, 0x00, 0x18, 0x53, 0x81, 0x23, 0x41, 0x00, 0x18,
                      0x41, 0xE9, 0x00, 0x08, 0x4E, 0x42, 0x23, 0x43, 0x00, 0x18, 0x23, 0x42, 0x00, 0x08, 0x24, 0xA9,
                      0x00, 0x14, 0x4E, 0xD4};
  // Check header record. Default header is similar to example.
  auto sro = File(0, data, 52);
  auto ofs = std::ofstream("srec_file_test.srec");
  sro.write(&ofs);
  ofs.close();
  auto ifs = std::ifstream("srec_file_test.srec");
  auto sri = File(&ifs);
  uint8_t* result;
  size_t size;
  sri.ToBuffer(&result, &size);
  ASSERT_EQ(memcmp(data, result, 52), 0);
  free(result);
}

TEST(SREC, RecordBatchRoundTrip) {
  // Get a recordbatch with some integers
  auto rb = fletcher::GetStringRB();
  // Open an Arrow FileOutputStream
  arrow::Result<std::shared_ptr<arrow::io::OutputStream>> result = arrow::io::FileOutputStream::Open("test.rbf");

  EXPECT_TRUE(result.ok());
  std::shared_ptr<arrow::io::OutputStream> aos = result.ValueOrDie();
  // Create a RecordBatchFile writer
  arrow::Result<std::shared_ptr<arrow::ipc::RecordBatchWriter>> afw = arrow::ipc::NewFileWriter(aos.get(), rb->schema());
  EXPECT_TRUE(afw.ok());

  // Write the RecordBatch to the FileOutputStream
  EXPECT_TRUE(afw.ValueOrDie()->WriteRecordBatch(*rb).ok());
}

}  // namespace fletchgen::srec
