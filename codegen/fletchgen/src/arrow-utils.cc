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

#include <utility>
#include <iostream>
#include <algorithm>

#include "arrow-utils.h"

using vhdl::Value;

namespace fletchgen {

Value getWidth(arrow::DataType *type) {

  // Fixed-width:
  if (type->id() == arrow::Type::BOOL) return Value(1);
  else if (type->id() == arrow::Type::DATE32) return Value(32);
  else if (type->id() == arrow::Type::DATE64) return Value(64);
  else if (type->id() == arrow::Type::DOUBLE) return Value(64);
  else if (type->id() == arrow::Type::FLOAT) return Value(32);
  else if (type->id() == arrow::Type::HALF_FLOAT) return Value(16);
  else if (type->id() == arrow::Type::INT8) return Value(8);
  else if (type->id() == arrow::Type::INT16) return Value(16);
  else if (type->id() == arrow::Type::INT32) return Value(32);
  else if (type->id() == arrow::Type::INT64) return Value(64);
  else if (type->id() == arrow::Type::TIME32) return Value(32);
  else if (type->id() == arrow::Type::TIME64) return Value(64);
  else if (type->id() == arrow::Type::TIMESTAMP) return Value(64);
  else if (type->id() == arrow::Type::UINT8) return Value(8);
  else if (type->id() == arrow::Type::UINT16) return Value(16);
  else if (type->id() == arrow::Type::UINT32) return Value(32);
  else if (type->id() == arrow::Type::UINT64) return Value(64);

    // Lists:
  else if (type->id() == arrow::Type::LIST) return Value("INDEX_WIDTH");
  else if (type->id() == arrow::Type::BINARY) return Value("INDEX_WIDTH");
  else if (type->id() == arrow::Type::STRING) return Value("INDEX_WIDTH");

    // Others:
    //if (type->id() == arrow::Type::INTERVAL) return 0;
    //if (type->id() == arrow::Type::MAP) return 0;
    //if (type->id() == arrow::Type::NA) return 0;
    //if (type->id() == arrow::Type::DICTIONARY) return 0;
    //if (type->id() == arrow::Type::UNION) return 0;


    // Structs have no width
  else if (type->id() == arrow::Type::STRUCT) return Value(0);

  else if (type->id() == arrow::Type::FIXED_SIZE_BINARY) {
    auto t = dynamic_cast<arrow::FixedSizeBinaryType *>(type);
    return Value(t->bit_width());
  } else if (type->id() == arrow::Type::DECIMAL) {
    auto t = dynamic_cast<arrow::DecimalType *>(type);
    return Value(t->bit_width());
  }

  return Value(-1);
}

int getEPC(arrow::Field *field) {
  int epc = 1;
  auto strepc = getMeta(field, "epc");
  if (!strepc.empty()) {
    epc = stoi(strepc);
  }
  return epc;
}

ConfigType getConfigType(arrow::DataType *type) {

  ConfigType ret = ConfigType::PRIM;

  /* Fixed-width:
  if (type->id() == arrow::Type::BOOL)
  if (type->id() == arrow::Type::DATE32)
  if (type->id() == arrow::Type::DATE64)
  if (type->id() == arrow::Type::DOUBLE)
  if (type->id() == arrow::Type::FLOAT)
  if (type->id() == arrow::Type::HALF_FLOAT)
  if (type->id() == arrow::Type::INT8)
  if (type->id() == arrow::Type::INT16)
  if (type->id() == arrow::Type::INT32)
  if (type->id() == arrow::Type::INT64)
  if (type->id() == arrow::Type::TIME32)
  if (type->id() == arrow::Type::TIME64)
  if (type->id() == arrow::Type::TIMESTAMP)
  if (type->id() == arrow::Type::UINT8)
  if (type->id() == arrow::Type::UINT16)
  if (type->id() == arrow::Type::UINT32)
  if (type->id() == arrow::Type::UINT64)
  if (type->id() == arrow::Type::FIXED_SIZE_BINARY)
  if (type->id() == arrow::Type::DECIMAL)
  */

  // Lists:
  if (type->id() == arrow::Type::LIST) ret = ConfigType::LIST;
  else if (type->id() == arrow::Type::BINARY) ret = ConfigType::LISTPRIM;
  else if (type->id() == arrow::Type::STRING) ret = ConfigType::LISTPRIM;

    // Others:
    //if (type->id() == arrow::Type::INTERVAL) return 0;
    //if (type->id() == arrow::Type::MAP) return 0;
    //if (type->id() == arrow::Type::NA) return 0;
    //if (type->id() == arrow::Type::DICTIONARY) return 0;
    //if (type->id() == arrow::Type::UNION) return 0;

    // Structs
  else if (type->id() == arrow::Type::STRUCT) ret = ConfigType::STRUCT;

  return ret;
}

std::string genConfigString(arrow::Field *field, int level) {
  std::string ret;
  ConfigType ct = getConfigType(field->type().get());

  if (field->nullable()) {
    ret += "null(";
    level++;
  }

  int epc = getEPC(field);

  //if (ct == ARB) return "arb";
  //else if (ct == NUL) return "null";
  //else

  if (ct == ConfigType::PRIM) {
    Value w = getWidth(field->type().get());

    ret += "prim(" + w.toString();
    level++;

  } else if (ct == ConfigType::LISTPRIM) {
    ret += "listprim(";
    level++;

    Value w = Value(8);

    ret += w.toString();
  } else if (ct == ConfigType::LIST) {
    ret += "list(";
    level++;
  } else if (ct == ConfigType::STRUCT) {
    ret += "struct(";
    level++;
  }

  if (epc > 1) {
    ret += ";epc=" + std::to_string(epc);
  }

  // Append children
  for (int c = 0; c < field->type()->num_children(); c++) {
    auto child = field->type()->children()[c];
    ret += genConfigString(child.get());
    if (c != field->type()->num_children() - 1)
      ret += ",";
  }

  for (; level > 0; level--)
    ret += ")";

  return ret;
}

std::string getMeta(arrow::Schema *schema, const std::string &key) {
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

std::string getMeta(arrow::Field *field, const std::string &key) {
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

Mode getMode(arrow::Schema *schema) {
  Mode mode = Mode::READ;
  if (getMeta(schema, "fletcher_mode") == "write") {
    mode = Mode::WRITE;
  }
  return mode;
}

bool mustIgnore(arrow::Field *field) {
  bool ret = false;
  if (getMeta(field, "fletcher_ignore") == "true") {
    ret = true;
  }
  return ret;
}

std::string getModeString(Mode mode) {
  if (mode == Mode::READ) {
    return "read";
  } else {
    return "write";
  }
}

std::shared_ptr<arrow::Schema> readSchemaFromFile(const std::string &file_name) {
  std::shared_ptr<arrow::Schema> schema_to_read;
  std::shared_ptr<arrow::io::ReadableFile> fis;
  if (arrow::io::ReadableFile::Open(file_name, &fis).ok()) {
    if (arrow::ipc::ReadSchema(fis.get(), &schema_to_read).ok()) {
      return schema_to_read;
    } else {
      throw std::runtime_error("Could not read schema from file input stream.");
    }
  } else {
    throw std::runtime_error("Could not open schema file for reading: " + file_name);
  }
}

void writeSchemaToFile(const std::shared_ptr<arrow::Schema> &schema, const std::string &file_name) {
  std::shared_ptr<arrow::Buffer> buffer;
  arrow::AllocateResizableBuffer(arrow::default_memory_pool(), 0,
                                 reinterpret_cast<std::shared_ptr<arrow::ResizableBuffer> *>(&buffer));

  if (!arrow::ipc::SerializeSchema(*schema, arrow::default_memory_pool(), &buffer).ok()) {
    throw std::runtime_error("Could not serialize schema into buffer.");
  }

  std::shared_ptr<arrow::io::FileOutputStream> fos;
  if (arrow::io::FileOutputStream::Open(file_name, &fos).ok()) {
    if (!fos->Write(buffer->data(), buffer->size()).ok()) {
      throw std::runtime_error("Could not write schema buffer to file output stream.");
    }
  } else {
    throw std::runtime_error("Could not open schema file for writing: " + file_name);
  }
}

std::shared_ptr<arrow::KeyValueMetadata> metaMode(Mode mode) {
  std::vector<std::string> keys = {"fletcher_mode"};
  std::vector<std::string> values;
  if (mode == Mode::READ)
    values = {"read"};
  else
    values = {"write"};
  return std::make_shared<arrow::KeyValueMetadata>(keys, values);
}

std::shared_ptr<arrow::KeyValueMetadata> metaEPC(int epc) {
  std::vector<std::string> epc_keys = {"epc"};
  std::vector<std::string> epc_values = {std::to_string(epc)};
  return std::make_shared<arrow::KeyValueMetadata>(epc_keys, epc_values);
}

std::shared_ptr<arrow::KeyValueMetadata> metaIgnore() {
  std::vector<std::string> ignore_key = {"fletcher_ignore"};
  std::vector<std::string> ignore_value = {"true"};
  return std::make_shared<arrow::KeyValueMetadata>(ignore_key, ignore_value);
}

}//namespace fletchgen
