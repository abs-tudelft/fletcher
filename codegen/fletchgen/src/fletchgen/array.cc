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

#include "fletchgen/array.h"

#include <memory>
#include <cerata/api.h>

#include "fletchgen/bus.h"

namespace fletchgen {

using cerata::Parameter;
using cerata::Literal;
using cerata::Port;
using cerata::PortArray;
using cerata::integer;
using cerata::string;
using cerata::intl;
using cerata::strl;
using cerata::boolean;
using cerata::bool_true;
using cerata::bool_false;

std::shared_ptr<Component> ArrayReader() {
  static auto ret = Component::Make("ArrayReader",
                                    {bus_addr_width(), bus_len_width(), bus_data_width(),
                                     Parameter::Make("BUS_BURST_STEP_LEN", integer(), intl<4>()),
                                     Parameter::Make("BUS_BURST_MAX_LEN", integer(), intl<16>()),
                                     Parameter::Make("INDEX_WIDTH", integer(), intl<32>()),
                                     Parameter::Make("CFG", string(), strl("\"\"")),
                                     Parameter::Make("CMD_TAG_ENABLE", boolean(), bool_false()),
                                     Parameter::Make("CMD_TAG_WIDTH", integer(), intl<1>()),
                                     Port::Make(bus_clk()),
                                     Port::Make(bus_reset()),
                                     Port::Make(acc_clk()),
                                     Port::Make(acc_reset()),
                                     Port::Make("bus_rreq", bus_read_request(), Port::Dir::OUT),
                                     Port::Make("bus_rdat", bus_read_data(), Port::Dir::IN),
                                     Port::Make("cmd", cmd(), Port::Dir::IN),
                                     Port::Make("unlock", unlock(), Port::Dir::OUT),
                                     Port::Make("out", read_data(), Port::Dir::OUT)}
  );
  ret->meta["primitive"] = "true";
  ret->meta["library"] = "work";
  ret->meta["package"] = "Arrays";
  return ret;
}

ConfigType GetConfigType(const arrow::DataType *type) {
  ConfigType ret = ConfigType::PRIM;

  // Lists:
  if (type->id() == arrow::Type::LIST) ret = ConfigType::LIST;
  else if (type->id() == arrow::Type::BINARY) ret = ConfigType::LISTPRIM;
  else if (type->id() == arrow::Type::STRING) ret = ConfigType::LISTPRIM;

    // Structs
  else if (type->id() == arrow::Type::STRUCT) ret = ConfigType::STRUCT;

  return ret;
}

std::shared_ptr<Node> GetWidth(const arrow::DataType *type) {
  switch (type->id()) {
    // Fixed-width:
    case arrow::Type::BOOL: return intl<1>();
    case arrow::Type::DATE32: return intl<32>();
    case arrow::Type::DATE64: return intl<64>();
    case arrow::Type::DOUBLE: return intl<64>();
    case arrow::Type::FLOAT: return intl<32>();
    case arrow::Type::HALF_FLOAT: return intl<16>();
    case arrow::Type::INT8: return intl<8>();
    case arrow::Type::INT16: return intl<16>();
    case arrow::Type::INT32: return intl<32>();
    case arrow::Type::INT64: return intl<64>();
    case arrow::Type::TIME32: return intl<32>();
    case arrow::Type::TIME64: return intl<64>();
    case arrow::Type::TIMESTAMP: return intl<64>();
    case arrow::Type::UINT8: return intl<8>();
    case arrow::Type::UINT16: return intl<16>();
    case arrow::Type::UINT32: return intl<32>();
    case arrow::Type::UINT64: return intl<64>();

      // Lists:
    case arrow::Type::LIST: return strl("OFFSET_WIDTH");
    case arrow::Type::BINARY: return strl("OFFSET_WIDTH");
    case arrow::Type::STRING: return strl("OFFSET_WIDTH");

      // Others:
    default:
      //case arrow::Type::INTERVAL: return 0;
      //case arrow::Type::MAP: return 0;
      //case arrow::Type::NA: return 0;
      //case arrow::Type::DICTIONARY: return 0;
      //case arrow::Type::UNION: return 0;
      throw std::domain_error("Arrow type " + type->ToString() + " not supported.");

      // Structs have no width
    case arrow::Type::STRUCT: return intl<0>();

      // Other width types:
    case arrow::Type::FIXED_SIZE_BINARY: {
      auto t = dynamic_cast<const arrow::FixedSizeBinaryType *>(type);
      return Literal::Make(t->bit_width());
    }
    case arrow::Type::DECIMAL: {
      auto t = dynamic_cast<const arrow::DecimalType *>(type);
      return Literal::Make(t->bit_width());
    }
  }
}

std::string GenerateConfigString(const std::shared_ptr<arrow::Field> &field, int level) {
  std::string ret;
  ConfigType ct = GetConfigType(field->type().get());

  if (field->nullable()) {
    ret += "null(";
    level++;
  }

  int epc = fletcher::getEPC(field);

  if (ct == ConfigType::PRIM) {
    auto w = GetWidth(field->type().get());
    ret += "prim(" + w->ToString();
    level++;
  } else if (ct == ConfigType::LISTPRIM) {
    ret += "listprim(8";
    level++;
  } else if (ct == ConfigType::LIST) {
    if (GetConfigType(field->type()->child(0)->type().get()) == ConfigType::PRIM) {
      ret += "list";
    } else {
      ret += "list(";
    }
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
    auto child = field->type()->child(c);
    ret += GenerateConfigString(child);
    if (c != field->type()->num_children() - 1)
      ret += ",";
  }

  for (; level > 0; level--)
    ret += ")";

  return ret;
}

}  // namespace fletchgen
