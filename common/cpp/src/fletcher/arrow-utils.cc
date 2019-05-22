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

#include <arrow/type.h>
#include <arrow/buffer.h>
#include <arrow/record_batch.h>
#include <arrow/io/api.h>
#include <arrow/ipc/api.h>

#include "fletcher/arrow-utils.h"

namespace fletcher {

void FlattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::ArrayData> &array_data) {
  for (const auto &buf : array_data->buffers) {
    auto addr = buf.get();
    if (addr != nullptr) {
      buffers->push_back(addr);
    }
  }
  for (const auto &child : array_data->child_data) {
    FlattenArrayBuffers(buffers, child);
  }
}

void FlattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::Array> &array) {
  // Because Arrow buffer order seems to be by convention and not by specification, handle these special cases:
  // This is to reverse the order of offset and values buffer to correspond with the hardware implementation.
  if (array->type_id() == arrow::BinaryType::type_id) {
    auto ba = std::static_pointer_cast<arrow::BinaryArray>(array);
    buffers->push_back(ba->value_offsets().get());
    buffers->push_back(ba->value_data().get());
  } else if (array->type_id() == arrow::StringType::type_id) {
    auto sa = std::static_pointer_cast<arrow::StringArray>(array);
    buffers->push_back(sa->value_offsets().get());
    buffers->push_back(sa->value_data().get());
  } else {
    for (const auto &buf : array->data()->buffers) {
      auto addr = buf.get();
      if (addr != nullptr) {
        buffers->push_back(addr);
      }
    }
    for (const auto &child : array->data()->child_data) {
      FlattenArrayBuffers(buffers, child);
    }
  }
}

void FlattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::ArrayData> &array_data,
                         const std::shared_ptr<arrow::Field> &field) {
  size_t b = 0;
  if (!field->nullable()) {
    b = 1;
  } else if (array_data->null_count == 0) {
    buffers->push_back(nullptr);
    b = 1;
  }
  for (; b < array_data->buffers.size(); b++) {
    auto addr = array_data->buffers[b].get();
    if (addr != nullptr) {
      buffers->push_back(addr);
    }
    for (size_t c = 0; c < array_data->child_data.size(); c++) {
      FlattenArrayBuffers(buffers, array_data->child_data[c], field->type()->child(static_cast<int>(c)));
    }
  }
}

void FlattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::Array> &array,
                         const std::shared_ptr<arrow::Field> &field) {
  if (field->type()->id() != array->type()->id()) {
    throw std::runtime_error("Incompatible schema.");
  }
  if (array->type_id() == arrow::BinaryType::type_id) {
    auto ba = std::static_pointer_cast<arrow::BinaryArray>(array);
    if (field->nullable() && (ba->null_count() == 0)) {
      buffers->push_back(nullptr);
    }
    buffers->push_back(ba->value_offsets().get());
    buffers->push_back(ba->value_data().get());
  } else if (array->type_id() == arrow::StringType::type_id) {
    auto sa = std::static_pointer_cast<arrow::StringArray>(array);
    if (field->nullable() && (sa->null_count() == 0)) {
      buffers->push_back(nullptr);
    }
    buffers->push_back(sa->value_offsets().get());
    buffers->push_back(sa->value_data().get());
  } else {
    size_t b = 0;
    if (!field->nullable()) {
      b = 1;
    } else if (array->null_count() == 0) {
      buffers->push_back(nullptr);
      b = 1;
    }
    for (; b < array->data()->buffers.size(); b++) {
      auto addr = array->data()->buffers[b].get();
      if (addr != nullptr) {
        buffers->push_back(addr);
      }
    }
    for (size_t c = 0; c < array->data()->child_data.size(); c++) {
      FlattenArrayBuffers(buffers, array->data()->child_data[c], field->type()->child(static_cast<int>(c)));
    }
  }
}

std::string GetMeta(const std::shared_ptr<arrow::Schema> &schema, const std::string &key) {
  if (schema->metadata() != nullptr) {
    std::unordered_map<std::string, std::string> meta;
    schema->metadata()->ToUnorderedMap(&meta);

    auto k = meta.find(key);
    if (k != meta.end()) {
      return k->second;
    }
  }
  // Return empty string if no metadata
  return "";
}

std::string GetMeta(const std::shared_ptr<arrow::Field> &field, const std::string &key) {
  if (field->metadata() != nullptr) {
    std::unordered_map<std::string, std::string> meta;
    field->metadata()->ToUnorderedMap(&meta);

    auto k = meta.find(key);
    if (k != meta.end()) {
      return k->second;
    }
  }
  // Return empty string if no metadata
  return "";
}

Mode GetMode(const std::shared_ptr<arrow::Schema> &schema) {
  Mode mode = Mode::READ;
  if (GetMeta(schema, "fletcher_mode") == "write") {
    mode = Mode::WRITE;
  }
  return mode;
}

bool MustIgnore(const std::shared_ptr<arrow::Field> &field) {
  bool ret = false;
  if (GetMeta(field, "fletcher_ignore") == "true") {
    ret = true;
  }
  return ret;
}

int GetIntMeta(const std::shared_ptr<arrow::Field> &field, std::string key, int default_to) {
  int ret = default_to;
  auto strepc = GetMeta(field, key);
  if (!strepc.empty()) {
    ret = stoi(strepc);
  }
  return ret;
}

std::shared_ptr<arrow::Schema> AppendMetaRequired(const std::shared_ptr<arrow::Schema> &schema,
                                                  std::string schema_name,
                                                  Mode mode) {
  std::vector<std::string> keys = {"fletcher_name", "fletcher_mode"};
  std::vector<std::string> values = {std::move(schema_name)};
  if (mode == Mode::READ)
    values.emplace_back("read");
  else
    values.emplace_back("write");
  auto meta = std::make_shared<arrow::KeyValueMetadata>(keys, values);
  return schema->AddMetadata(meta);
}

std::shared_ptr<arrow::Field> AppendMetaEPC(const std::shared_ptr<arrow::Field> &field, int epc) {
  auto meta = std::make_shared<arrow::KeyValueMetadata>(std::vector<std::string>({"fletcher_epc"}),
                                                        std::vector<std::string>({std::to_string(epc)}));
  return field->AddMetadata(meta);
}

std::shared_ptr<arrow::Field> AppendMetaIgnore(const std::shared_ptr<arrow::Field> &field) {
  const static std::vector<std::string> ignore_key = {"fletcher_ignore"};
  const static std::vector<std::string> ignore_value = {"true"};
  const static auto meta = std::make_shared<arrow::KeyValueMetadata>(ignore_key, ignore_value);
  return field->AddMetadata(meta);
}

std::vector<std::shared_ptr<arrow::Schema>> ReadSchemasFromFiles(const std::vector<std::string> &file_names) {
  std::vector<std::shared_ptr<arrow::Schema>> schemas;
  for (const auto &file_name : file_names) {
    std::shared_ptr<arrow::Schema> schema_to_read;
    std::shared_ptr<arrow::io::ReadableFile> fis;
    if (arrow::io::ReadableFile::Open(file_name, &fis).ok()) {
      if (arrow::ipc::ReadSchema(fis.get(), &schema_to_read).ok()) {
        schemas.push_back(schema_to_read);
      } else {
        throw std::runtime_error("Could not read schema " + file_name + " from file input stream.");
      }
    } else {
      throw std::runtime_error("Could not open schema file for reading: " + file_name);
    }
  }
  return schemas;
}

void WriteSchemaToFile(const std::shared_ptr<arrow::Schema> &schema, const std::string &file_name) {
  std::shared_ptr<arrow::ResizableBuffer> resizable_buffer;
  std::shared_ptr<arrow::io::FileOutputStream> fos;
  if (!arrow::AllocateResizableBuffer(arrow::default_memory_pool(), 0, &resizable_buffer).ok()) {
    throw std::runtime_error("Could not allocate resizable Arrow buffer.");
  }
  auto buffer = std::dynamic_pointer_cast<arrow::Buffer>(resizable_buffer);
  if (!arrow::ipc::SerializeSchema(*schema, arrow::default_memory_pool(), &buffer).ok()) {
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

void WriteRecordBatchToFile(const std::shared_ptr<arrow::RecordBatch> &recordbatch, const std::string &filename) {
  std::shared_ptr<arrow::ResizableBuffer> resizable_buffer;
  if (!arrow::AllocateResizableBuffer(arrow::default_memory_pool(), 0, &resizable_buffer).ok()) {
    throw std::runtime_error("Could not allocate resizable Arrow buffer.");
  }
  auto buffer = std::dynamic_pointer_cast<arrow::Buffer>(resizable_buffer);
  if (!arrow::ipc::SerializeRecordBatch(*recordbatch, arrow::default_memory_pool(), &buffer).ok()) {
    throw std::runtime_error("Could not serialize record batch into buffer.");
  }
  std::shared_ptr<arrow::io::FileOutputStream> fos;
  if (arrow::io::FileOutputStream::Open(filename, &fos).ok()) {
    if (!fos->Write(buffer->data(), buffer->size()).ok()) {
      throw std::runtime_error("Could not write buffer to file output stream.");
    }
  } else {
    throw std::runtime_error("Could not open file for writing: " + filename);
  }
}

std::shared_ptr<arrow::RecordBatch> ReadRecordBatchFromFile(const std::string &file_name,
                                                            const std::shared_ptr<arrow::Schema> &schema) {
  std::shared_ptr<arrow::RecordBatch> recordbatch_to_read;
  std::shared_ptr<arrow::io::ReadableFile> fis;
  if (arrow::io::ReadableFile::Open(file_name, &fis).ok()) {
    if (arrow::ipc::ReadRecordBatch(schema, fis.get(), &recordbatch_to_read).ok()) {
      return recordbatch_to_read;
    } else {
      throw std::runtime_error("Could not read RecordBatch from file input stream.");
    }
  } else {
    throw std::runtime_error("Could not open RecordBatch file for reading: " + file_name);
  }
}

void AppendExpectedBuffersFromField(std::vector<std::string> *buffers, const std::shared_ptr<arrow::Field> &field) {
  // Flatten in case this is a struct:
  auto flat_fields = field->Flatten();

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
        AppendExpectedBuffersFromField(buffers, f->type()->child(0));
      } else {
        buffers->push_back(f->name() + "_values");
      }
    }
  }
}

}  // namespace fletcher
