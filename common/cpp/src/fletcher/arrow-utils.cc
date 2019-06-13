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
#include <vector>
#include <iostream>

#include <arrow/api.h>
#include <arrow/io/api.h>
#include <arrow/ipc/api.h>

#include "fletcher/arrow-utils.h"
#include "fletcher/logging.h"

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
  if (GetMeta(schema, "fletcher_mode") == "write") {
    mode = Mode::WRITE;
  }
  return mode;
}

bool MustIgnore(const arrow::Field &field) {
  bool ret = false;
  if (GetMeta(field, "fletcher_ignore") == "true") {
    ret = true;
  }
  return ret;
}

int GetIntMeta(const arrow::Field &field, const std::string& key, int default_to) {
  int ret = default_to;
  auto strepc = GetMeta(field, key);
  if (!strepc.empty()) {
    ret = stoi(strepc);
  }
  return ret;
}

std::shared_ptr<arrow::Schema> AppendMetaRequired(const arrow::Schema &schema,
                                                  std::string schema_name,
                                                  Mode mode) {
  std::vector<std::string> keys = {"fletcher_name", "fletcher_mode"};
  std::vector<std::string> values = {std::move(schema_name)};
  if (mode == Mode::READ)
    values.emplace_back("read");
  else
    values.emplace_back("write");
  auto meta = std::make_shared<arrow::KeyValueMetadata>(keys, values);
  return schema.AddMetadata(meta);
}

std::shared_ptr<arrow::Field> AppendMetaEPC(const arrow::Field &field, int epc) {
  auto meta = std::make_shared<arrow::KeyValueMetadata>(std::vector<std::string>({"fletcher_epc"}),
                                                        std::vector<std::string>({std::to_string(epc)}));
  return field.AddMetadata(meta);
}

std::shared_ptr<arrow::Field> AppendMetaIgnore(const arrow::Field &field) {
  const static std::vector<std::string> ignore_key = {"fletcher_ignore"};
  const static std::vector<std::string> ignore_value = {"true"};
  const static auto meta = std::make_shared<arrow::KeyValueMetadata>(ignore_key, ignore_value);
  return field.AddMetadata(meta);
}

void ReadSchemaFromFile(const std::string &file_name, std::shared_ptr<arrow::Schema> *out) {
  std::shared_ptr<arrow::Schema> schema;
  std::shared_ptr<arrow::io::ReadableFile> fis;
  arrow::Status status;
  status = arrow::io::ReadableFile::Open(file_name, &fis);
  if (!status.ok()) {
    FLETCHER_LOG(ERROR, "Could not open file for reading: " + file_name + " ARROW:[" + status.ToString() + "]");
  }
  status = arrow::ipc::ReadSchema(fis.get(), out);
  if (!status.ok()) {
    FLETCHER_LOG(ERROR, "Could not read schema from file file: " + file_name + " ARROW:[" + status.ToString() + "]");
  }
  status = fis->Close();
}

void WriteSchemaToFile(const std::string &file_name, const arrow::Schema &schema) {
  std::shared_ptr<arrow::ResizableBuffer> resizable_buffer;
  std::shared_ptr<arrow::io::FileOutputStream> fos;
  if (!arrow::AllocateResizableBuffer(arrow::default_memory_pool(), 0, &resizable_buffer).ok()) {
    throw std::runtime_error("Could not allocate resizable Arrow buffer.");
  }
  auto buffer = std::dynamic_pointer_cast<arrow::Buffer>(resizable_buffer);
  if (!arrow::ipc::SerializeSchema(schema, arrow::default_memory_pool(), &buffer).ok()) {
    throw std::runtime_error("Could not serialize schema into buffer.");
  }
  if (arrow::io::FileOutputStream::Open(file_name, &fos).ok()) {
    if (!fos->Write(buffer->data(), buffer->size()).ok()) {
      throw std::runtime_error("Could not write schema buffer to file output stream.");
    }
  } else {
    throw std::runtime_error("Could not open schema file for writing: " + file_name);
  }
}

void WriteRecordBatchesToFile(const std::string &filename,
                              const std::vector<std::shared_ptr<arrow::RecordBatch>> &recordbatches) {
  arrow::Status status;
  std::shared_ptr<arrow::io::FileOutputStream> file;
  status = arrow::io::FileOutputStream::Open(filename, &file);
  for (const auto &rb : recordbatches) {
    std::shared_ptr<arrow::ipc::RecordBatchWriter> writer;
    status = arrow::ipc::RecordBatchFileWriter::Open(file.get(), rb->schema(), &writer);
    status = writer->WriteRecordBatch(*rb);
    status = writer->Close();
  }
  status = file->Close();
}

void ReadRecordBatchesFromFile(const std::string &file_name, std::vector<std::shared_ptr<arrow::RecordBatch>> *out) {
  arrow::Status status;
  std::shared_ptr<arrow::io::ReadableFile> file;
  std::shared_ptr<arrow::ipc::RecordBatchFileReader> reader;

  status = arrow::io::ReadableFile::Open(file_name, &file);
  if (!status.ok()) {
    FLETCHER_LOG(ERROR, "Could not open file for reading. " + file_name + " ARROW:[" + status.ToString() + "]");
    return;
  }

  status = arrow::ipc::RecordBatchFileReader::Open(file, &reader);
  if (!status.ok()) {
    FLETCHER_LOG(ERROR, "Could not open RecordBatchFileReader. ARROW:[" + status.ToString() + "]");
    return;
  }

  for (int i = 0; i < reader->num_record_batches(); i++) {
    std::shared_ptr<arrow::RecordBatch> recordbatch;
    status = reader->ReadRecordBatch(i, &recordbatch);
    if (!status.ok()) {
      FLETCHER_LOG(ERROR, "Could not read RecordBatch " << i << " from file. ARROW:[" + status.ToString() + "]");
    }
    out->push_back(recordbatch);
  }
}

void AppendExpectedBuffersFromField(std::vector<std::string> *buffers, const arrow::Field &field) {
  // Flatten in case this is a struct:
  auto flat_fields = field.Flatten();

  // Parse the flattened fields:
  for (const auto &f : flat_fields) {
    if (f->type() == arrow::utf8()) {
      buffers->push_back(f->name() + "_offsets");
      buffers->push_back(f->name() + "_values");
    } else if (f->type() == arrow::binary()) {
      buffers->push_back(f->name() + "_offsets");
      buffers->push_back(f->name() + "_values");
    } else {
      if (f->nullable()) {
        buffers->push_back(f->name() + "_validity");
      }
      if (f->type()->id() == arrow::ListType::type_id) {
        buffers->push_back(f->name() + "_offsets");
        AppendExpectedBuffersFromField(buffers, *f->type()->child(0));
      } else {
        buffers->push_back(f->name() + "_values");
      }
    }
  }
}

}  // namespace fletcher
