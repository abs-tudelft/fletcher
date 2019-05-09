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
#include <cmath>
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
using cerata::RecField;
using cerata::Vector;
using cerata::Type;
using cerata::Record;
using cerata::Stream;

std::shared_ptr<Node> ctrl_width(const std::shared_ptr<arrow::Field> &field) {
  std::vector<std::string> buffers;
  fletcher::appendExpectedBuffersFromField(&buffers, field);
  std::shared_ptr<Node> width = Literal::Make(buffers.size());
  return width * bus_addr_width();
}

std::shared_ptr<Type> cmd(const std::shared_ptr<Node> &ctrl_width, const std::shared_ptr<Node> &tag_width) {
  auto firstidx = RecField::Make(Vector::Make<32>("firstIdx"));
  auto lastidx = RecField::Make(Vector::Make<32>("lastidx"));
  auto ctrl = RecField::Make(Vector::Make("ctrl", ctrl_width));
  auto tag = RecField::Make(Vector::Make("tag", tag_width));
  auto cmd_record = Record::Make("command_rec", {firstidx, lastidx, ctrl, tag});
  auto result = Stream::Make("command", cmd_record);
  return result;
}

std::shared_ptr<Type> unlock(const std::shared_ptr<Node> &tag_width) {
  static auto tag = Vector::Make("tag", tag_width);
  static std::shared_ptr<Type> unlock_stream = Stream::Make("unlock", tag, "tag");
  return unlock_stream;
}

std::shared_ptr<Type> read_data(std::shared_ptr<Node> width) {
  static auto d = RecField::Make(data(std::move(width)));
  static auto dv = RecField::Make(dvalid());
  static auto l = RecField::Make(last());
  static auto data_record = Record::Make("ar_data_rec", {d, dv, l});
  static auto data_stream = Stream::Make("ar_data_stream", data_record);
  return data_stream;
}

std::shared_ptr<Type> write_data(std::shared_ptr<Node> width) {
  static auto d = RecField::Make(data(std::move(width)));
  static auto l = RecField::Make(last());
  static auto data_record = Record::Make("ar_data_rec", {d, l});
  static auto data_stream = Stream::Make("ar_data_stream", data_record);
  return data_stream;
}

std::shared_ptr<Component> ArrayReader(std::shared_ptr<Node> data_width,
                                       const std::shared_ptr<Node>& ctrl_width,
                                       const std::shared_ptr<Node> &tag_width) {
  static auto ret = Component::Make("ArrayReader",
                                    {bus_addr_width(), bus_len_width(), bus_data_width(),
                                     Parameter::Make("BUS_BURST_STEP_LEN", integer(), intl<4>()),
                                     Parameter::Make("BUS_BURST_MAX_LEN", integer(), intl<16>()),
                                     Parameter::Make("INDEX_WIDTH", integer(), intl<32>()),
                                     Parameter::Make("CFG", string(), strl("\"\"")),
                                     Parameter::Make("CMD_TAG_ENABLE", boolean(), bool_false()),
                                     Parameter::Make("CMD_TAG_WIDTH", integer(), intl<1>()),
                                     Port::Make(bus_cr()),
                                     Port::Make(kernel_cr()),
                                     BusPort::Make(BusPort::Function::READ, Port::Dir::OUT, BusSpec()),
                                     Port::Make("cmd", cmd(ctrl_width, tag_width), Port::Dir::IN),
                                     Port::Make("unlock", unlock(tag_width), Port::Dir::OUT),
                                     Port::Make("out", read_data(std::move(data_width)), Port::Dir::OUT)}
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

std::shared_ptr<TypeMapper> GetStreamTypeMapper(const std::shared_ptr<Type> &stream_type, fletcher::Mode mode) {
  std::shared_ptr<TypeMapper> conversion;
  if (mode == fletcher::Mode::READ) {
    conversion = std::make_shared<TypeMapper>(stream_type.get(), read_data().get());
  } else {
    conversion = std::make_shared<TypeMapper>(stream_type.get(), write_data().get());
  }

  size_t idx_stream = 0;
  // Unused: size_t idx_record = 1;
  size_t idx_data = 2;
  size_t idx_dvalid = 3;
  size_t idx_last = 4;

  auto flat_stream = conversion->flat_a();
  for (size_t i = 0; i < flat_stream.size(); i++) {
    auto t = flat_stream[i].type_;
    if (t->Is(Type::STREAM)) {
      conversion->Add(i, idx_stream);
    } else if (t == dvalid().get()) {
      conversion->Add(i, idx_dvalid);
    } else if (t == last().get()) {
      conversion->Add(i, idx_last);
    } else if (t->Is(Type::RECORD)) {
      // do nothing
    } else {
      // If it's not any of the default control signals on the stream, it must be data.
      conversion->Add(i, idx_data);
    }
  }
  return conversion;
}

std::shared_ptr<Type> GetStreamType(const std::shared_ptr<arrow::Field> &field, fletcher::Mode mode, int level) {
  // The ordering of the record fields in this function determines the order in which a nested stream is type converted
  // automatically using GetStreamTypeConverter. This corresponds to how the hardware is implemented.
  //
  // WARNING: Modifications to this function must be reflected in the manual hardware implementation of Fletcher
  // components! See: hardware/arrays/ArrayConfig.vhd

  int epc = fletcher::getEPC(field);

  std::shared_ptr<Type> type;

  auto arrow_id = field->type()->id();
  auto name = field->name();

  switch (arrow_id) {
    case arrow::Type::BINARY: {
      // Special case: binary type has a length stream and byte stream. The EPC is assumed to relate to the list
      // values, as there is no explicit child field to place this metadata in.

      std::shared_ptr<Node> count_width = Literal::Make(static_cast<int>(ceil(log2(epc + 1))));
      std::shared_ptr<Node> data_width = Literal::Make(epc * 8);

      auto slave = Stream::Make(name,
                                Record::Make("slave_rec", {
                                    RecField::Make("dvalid", dvalid()),
                                    RecField::Make("last", last()),
                                    RecField::Make("count", count(count_width)),
                                    RecField::Make("data", data(data_width))}),
                                "slave_stream", epc);
      type = Record::Make(name + "_rec", {
          RecField::Make("length", length()),
          RecField::Make("bytes", slave)
      });
      break;
    }

    case arrow::Type::STRING: {
      // Special case: string type has a length stream and utf8 character stream. The EPC is assumed to relate to the
      // list values, as there is no explicit child field to place this metadata in.

      std::shared_ptr<Node> count_width = Literal::Make(static_cast<int>(ceil(log2(epc + 1))));
      std::shared_ptr<Node> data_width = Literal::Make(epc * 8);

      auto slave = Stream::Make(name,
                                Record::Make("slave_rec", {
                                    RecField::Make("dvalid", dvalid()),
                                    RecField::Make("last", last()),
                                    RecField::Make("count", count(count_width)),
                                    RecField::Make("data", data(data_width))}),
                                "slave_stream", epc);
      type = Record::Make(name + "_rec", {
          RecField::Make("length", length()),
          RecField::Make("chars", slave)
      });
      break;
    }

      // Lists
    case arrow::Type::LIST: {
      if (field->type()->num_children() != 1) {
        throw std::runtime_error("Encountered Arrow list type with other than 1 child.");
      }

      auto arrow_child = field->type()->child(0);
      auto element_type = GetStreamType(arrow_child, mode, level + 1);
      auto slave = Stream::Make(name,
                                Record::Make("slave_rec", {
                                    RecField::Make("dvalid", dvalid()),
                                    RecField::Make("last", last()),
                                    RecField::Make("data", element_type)}),
                                "slave_stream", epc);
      type = Record::Make(name + "_rec", {
          RecField::Make("length", length()),
          RecField::Make(arrow_child->name(), slave)
      });
      break;
    }

      // Structs
    case arrow::Type::STRUCT: {
      if (field->type()->num_children() < 1) {
        throw std::runtime_error("Encountered Arrow struct type without any children.");
      }
      std::deque<std::shared_ptr<RecField>> children;
      for (const auto &f : field->type()->children()) {
        auto child_type = GetStreamType(f, mode, level + 1);
        children.push_back(RecField::Make(f->name(), child_type));
      }
      type = Record::Make(name + "_rec", children);
      break;
    }

      // Non-nested types
    default: {
      type = GenTypeFrom(field->type());
      break;
    }
  }

  // If this is a top level field, create a stream out of it
  if (level == 0) {
    // Element name is empty by default.
    std::string elements_name;
    // Check if the type is nested. If it is not nested, the give the elements the name "data"
    if (!type->IsNested()) {
      elements_name = "data";
    }
    // Create the stream record
    auto record = Record::Make("data", {
        RecField::Make("dvalid", dvalid()),
        RecField::Make("last", last()),
        RecField::Make(elements_name, type)});
    auto stream = Stream::Make(name, record, elements_name);
    stream->AddMapper(GetStreamTypeMapper(stream, mode));
    return stream;
  } else {
    // Otherwise just return the type
    return type;
  }
}

}  // namespace fletchgen
