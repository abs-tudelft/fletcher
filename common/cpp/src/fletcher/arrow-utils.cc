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

#include <arrow/api.h>
#include <arrow/io/api.h>
#include <arrow/ipc/api.h>

#include <utility>
#include <memory>
#include <vector>
#include <iostream>
#include <unordered_map>
#include <sstream>

#include "fletcher/arrow-utils.h"
#include "fletcher/logging.h"
#include "fletcher/meta/meta.h"

namespace fletcher {

std::string GetMeta(const arrow::Schema &schema, const std::string &key) {
  if (schema.metadata() != nullptr) {
    std::unordered_map<std::string, std::string> meta;
    schema.metadata()->ToUnorderedMap(&meta);

    auto k = meta.find(key);
    if (k != meta.end()) {
      return k->second;
    }
  }
  // Return empty string if no metadata
  return "";
}

std::string GetMeta(const arrow::Field &field, const std::string &key) {
  if (field.metadata() != nullptr) {
    std::unordered_map<std::string, std::string> meta;
    field.metadata()->ToUnorderedMap(&meta);
    auto k = meta.find(key);
    if (k != meta.end()) {
      return k->second;
    }
  }
  // Return empty string if no metadata
  return "";
}

Mode GetMode(const arrow::Schema &schema) {
  Mode mode = Mode::READ;
  if (GetMeta(schema, fletcher::meta::MODE) == "write") {
    mode = Mode::WRITE;
  }
  return mode;
}

uint64_t GetUIntMeta(const arrow::Field &field, const std::string &key, int default_to) {
  int ret = default_to;
  auto str = GetMeta(field, key);
  if (!str.empty()) {
    ret = std::stoul(str, nullptr, 10);
  }
  return ret;
}

int64_t GetIntMeta(const arrow::Field &field, const std::string &key, int default_to) {
  int ret = default_to;
  auto str = GetMeta(field, key);
  if (!str.empty()) {
    ret = std::stol(str, nullptr, 10);
  }
  return ret;
}

bool GetBoolMeta(const arrow::Field &field, const std::string &key, bool default_to) {
  auto str = GetMeta(field, key);
  if (!str.empty()) {
    if (str == "true") {
      return true;
    }
    if (str == "false") {
      return false;
    }
  }
  return default_to;
}

std::shared_ptr<arrow::Schema> WithMetaRequired(const arrow::Schema &schema,
                                                std::string schema_name,
                                                Mode mode) {
  std::vector<std::string> keys = {meta::NAME, meta::MODE};
  std::vector<std::string> values = {std::move(schema_name)};
  if (mode == Mode::READ)
    values.emplace_back(meta::READ);
  else
    values.emplace_back(meta::WRITE);
  auto meta = std::make_shared<arrow::KeyValueMetadata>(keys, values);
  return schema.WithMetadata(meta);
}

std::shared_ptr<arrow::Schema> WithMetaBusSpec(const arrow::Schema &schema,
                                               int aw,
                                               int dw,
                                               int sw,
                                               int lw,
                                               int bs,
                                               int bm) {
  std::stringstream ss;
  ss << aw << "," << aw << "," << dw << "," << sw << "," << lw << "," << bs << "," << bm;
  auto meta = std::make_shared<arrow::KeyValueMetadata>(std::vector<std::string>({meta::BUS_SPEC}),
                                                        std::vector<std::string>({ss.str()}));
  return schema.WithMetadata(meta);
}

std::shared_ptr<arrow::Field> WithMetaEPC(const arrow::Field &field, int epc) {
  auto meta = std::make_shared<arrow::KeyValueMetadata>(
      std::vector<std::string>({meta::VALUE_EPC}),
      std::vector<std::string>({std::to_string(epc)}));
  return field.WithMetadata(meta);
}

std::shared_ptr<arrow::Field> WithMetaIgnore(const arrow::Field &field) {
  std::vector<std::string> ignore_key = {meta::IGNORE};
  std::vector<std::string> ignore_value = {"true"};
  auto meta = std::make_shared<arrow::KeyValueMetadata>(ignore_key, ignore_value);
  return field.WithMetadata(meta);
}

std::shared_ptr<arrow::Field> WithMetaProfile(const arrow::Field &field) {
  std::vector<std::string> profile_key = {meta::PROFILE};
  std::vector<std::string> profile_value = {"true"};
  auto meta = std::make_shared<arrow::KeyValueMetadata>(profile_key, profile_value);
  return field.WithMetadata(meta);
}

bool ReadSchemaFromFile(const std::string &file_name, std::shared_ptr<arrow::Schema> *out) {
  std::shared_ptr<arrow::Schema> schema;
  arrow::Result<std::shared_ptr<arrow::io::ReadableFile>> result = arrow::io::ReadableFile::Open(file_name);
  if (!result.ok()) {
    FLETCHER_LOG(ERROR, "Could not open file for reading: " + file_name + " ARROW:[" + result.status().ToString() + "]");
    return false;
  }
  std::shared_ptr<arrow::io::ReadableFile> fis = result.ValueOrDie();

  // Dictionaries are not supported yet, hence nullptr.
  arrow::Status status;
  status = arrow::ipc::ReadSchema(fis.get(), nullptr, out);
  if (!status.ok()) {
    FLETCHER_LOG(ERROR, "Could not read schema from file file: " + file_name + " ARROW:[" + status.ToString() + "]");
    return false;
  }
  status = fis->Close();

  return true;
}

void WriteSchemaToFile(const std::string &file_name, const arrow::Schema &schema) {
  std::shared_ptr<arrow::ResizableBuffer> resizable_buffer;
  if (!arrow::AllocateResizableBuffer(arrow::default_memory_pool(), 0, &resizable_buffer).ok()) {
    throw std::runtime_error("Could not allocate resizable Arrow buffer.");
  }
  auto buffer = std::dynamic_pointer_cast<arrow::Buffer>(resizable_buffer);
  // Dictionaries are not supported yet, hence nullptr.
  if (!arrow::ipc::SerializeSchema(schema, nullptr, arrow::default_memory_pool(), &buffer).ok()) {
    throw std::runtime_error("Could not serialize schema into buffer.");
  }
  arrow::Result<std::shared_ptr<arrow::io::FileOutputStream>> result = arrow::io::FileOutputStream::Open(file_name);
  if (result.ok()) {
    std::shared_ptr<arrow::io::FileOutputStream> fos = result.ValueOrDie();
    if (!fos->Write(buffer->data(), buffer->size()).ok()) {
      throw std::runtime_error("Could not write schema buffer to file output stream.");
    }
  } else {
    throw std::runtime_error("Could not open schema file for writing: " + file_name);
  }
}

void WriteRecordBatchesToFile(const std::string &filename,
                              const std::vector<std::shared_ptr<arrow::RecordBatch>> &recordbatches) {
  arrow::Result<std::shared_ptr<arrow::io::FileOutputStream>> result = arrow::io::FileOutputStream::Open(filename);
  std::shared_ptr<arrow::io::FileOutputStream> file = result.ValueOrDie();

  arrow::Status status;

  for (const auto &rb : recordbatches) {
    std::shared_ptr<arrow::ipc::RecordBatchWriter> writer;
    status = arrow::ipc::RecordBatchFileWriter::Open(file.get(), rb->schema(), &writer);
    status = writer->WriteRecordBatch(*rb);
    status = writer->Close();
  }
  status = file->Close();
}

bool ReadRecordBatchesFromFile(const std::string &file_name, std::vector<std::shared_ptr<arrow::RecordBatch>> *out) {
  arrow::Status status;
  std::shared_ptr<arrow::ipc::RecordBatchFileReader> reader;

  arrow::Result<std::shared_ptr<arrow::io::ReadableFile>> result = arrow::io::ReadableFile::Open(file_name);
  if (!result.ok()) {
    FLETCHER_LOG(ERROR, "Could not open file for reading: " + file_name + " ARROW:[" + result.status().ToString() + "]");
    return false;
  }
  std::shared_ptr<arrow::io::ReadableFile> file = result.ValueOrDie();

  status = arrow::ipc::RecordBatchFileReader::Open(file, &reader);
  if (!status.ok()) {
    FLETCHER_LOG(ERROR, "Could not open RecordBatchFileReader. ARROW:[" + status.ToString() + "]");
    return false;
  }

  for (int i = 0; i < reader->num_record_batches(); i++) {
    std::shared_ptr<arrow::RecordBatch> recordbatch;
    status = reader->ReadRecordBatch(i, &recordbatch);
    if (!status.ok()) {
      FLETCHER_LOG(ERROR, "Could not read RecordBatch " << i << " from file. ARROW:[" + status.ToString() + "]");
      return false;
    }
    out->push_back(recordbatch);
  }

  return true;
}

std::string ToString(const std::vector<std::string> &strvec, const std::string &sep) {
  std::string result;
  for (const auto &s : strvec) {
    result += s;
    if (s != strvec.back()) {
      result += sep;
    }
  }
  return result;
}

}  // namespace fletcher
