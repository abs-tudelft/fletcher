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

#include <cerata/api.h>
#include <fletcher/common.h>
#include <memory>
#include <cmath>
#include <vector>
#include <deque>
#include <string>

#include "fletchgen/bus.h"

namespace fletchgen {

using fletcher::Mode;

using cerata::Parameter;
using cerata::Literal;
using cerata::Port;
using cerata::PortArray;
using cerata::integer;
using cerata::string;
using cerata::intl;
using cerata::strl;
using cerata::booll;
using cerata::boolean;
using cerata::RecField;
using cerata::Vector;
using cerata::Type;
using cerata::Record;
using cerata::Stream;

std::shared_ptr<Node> ctrl_width(const arrow::Field &field) {
  fletcher::FieldMetadata field_meta;
  fletcher::FieldAnalyzer fa(&field_meta);
  fa.Analyze(field);
  std::shared_ptr<Node> width = intl(field_meta.buffers.size());
  return width * bus_addr_width();
}

std::shared_ptr<Node> tag_width(const arrow::Field &field) {
  auto meta_val = fletcher::GetMeta(field, "tag_width");
  if (meta_val.empty()) {
    return intl(1);
  } else {
    return Literal::MakeInt(std::stoi(meta_val));
  }
}

std::shared_ptr<Type> cmd(const std::shared_ptr<Node> &tag_width = intl(1),
                          const std::optional<std::shared_ptr<Node>> &ctrl_width) {
  // Create fields
  auto firstidx = RecField::Make(Vector::Make("firstIdx", 32));
  auto lastidx = RecField::Make(Vector::Make("lastidx", 32));
  auto tag = RecField::Make(Vector::Make("tag", tag_width));

  // Create record
  auto cmd_record = Record::Make("command_rec", {firstidx, lastidx, tag});

  // If we want the ctrl field to be visible on this type, create that as well. This field is used to pass addresses.
  // Depending on how advanced the developer is, we want to expose this or leave it out through the Nucleus layer.
  if (ctrl_width) {
    auto ctrl = RecField::Make(Vector::Make("ctrl", *ctrl_width));
    cmd_record->AddField(ctrl, 2);
  }

  // Create the stream type.
  auto result = Stream::Make("command", cmd_record);
  return result;
}

std::shared_ptr<Type> unlock(const std::shared_ptr<Node> &tag_width) {
  auto tag = Vector::Make("tag", tag_width);
  std::shared_ptr<Type> unlock_stream = Stream::Make("unlock", tag, "tag");
  return unlock_stream;
}

std::shared_ptr<Type> read_data(const std::shared_ptr<Node> &width) {
  auto d = RecField::Make(data(width));
  auto dv = RecField::Make(dvalid());
  auto l = RecField::Make(last());
  auto data_record = Record::Make("ARRecord", {d, dv, l});
  auto data_stream = Stream::Make("ARData", data_record);
  data_stream->meta[cerata::vhdl::metakeys::FORCE_VECTOR] = "true";
  return data_stream;
}

std::shared_ptr<Type> write_data(const std::shared_ptr<Node> &width) {
  auto d = RecField::Make(data(width));
  auto dv = RecField::Make(dvalid());
  auto l = RecField::Make(last());
  auto data_record = Record::Make("AWRecord", {d, dv, l});
  auto data_stream = Stream::Make("AWData", data_record);
  data_stream->meta[cerata::vhdl::metakeys::FORCE_VECTOR] = "true";
  return data_stream;
}

static std::string ArrayName(fletcher::Mode mode) {
  std::string result = mode == Mode::READ ? "ArrayReader" : "ArrayWriter";
  return result;
}

static std::string DataName(fletcher::Mode mode) {
  std::string result = mode == Mode::READ ? "out" : "in";
  return result;
}

/**
 * @brief Return a Cerata component model of an Array(Reader/Writer).
 *
 *  * This model corresponds to either:
 *    [`hardware/arrays/ArrayReader.vhd`](https://github.com/johanpel/fletcher/blob/develop/hardware/arrays/ArrayReader.vhd)
 * or [`hardware/arrays/ArrayWriter.vhd`](https://github.com/johanpel/fletcher/blob/develop/hardware/arrays/ArrayWriter.vhd)
 * depending on the mode parameter.
 *
 * Changes to the implementation of this component in the HDL source must be reflected in the implementation of this
 * function.
 *
 * @param mode        Whether this Array component must Read or Write.
 * @return            The component model.
 */
static std::shared_ptr<Component> Array(Mode mode) {
  std::shared_ptr<BusPort> bus;
  std::shared_ptr<Port> data;

  BusSpec spec{};

  if (mode == Mode::READ) {
    spec.function = BusFunction::READ;
    data = Port::Make(DataName(mode), read_data(), Port::Dir::OUT, kernel_cd());
    bus = BusPort::Make(Port::Dir::OUT, spec);
  } else {
    spec.function = BusFunction::WRITE;
    data = Port::Make(DataName(mode), write_data(), Port::Dir::IN, kernel_cd());
    bus = BusPort::Make(Port::Dir::OUT, spec);
  }

  std::deque<std::shared_ptr<cerata::Object>> objects;

  // Insert some parameters
  objects.insert(objects.end(), {bus_addr_width(), bus_len_width(), bus_data_width()});

  // Insert bus strobe width for writers
  if (mode == Mode::WRITE) {
    objects.push_back(bus_strobe_width());
  }

  // Insert other parameters
  // TODO(johanpel): should be customizable and propagated from some user-defined arguments/settings
  objects.insert(objects.end(), {
      Parameter::Make("BUS_BURST_STEP_LEN", integer(), intl(1)),
      Parameter::Make("BUS_BURST_MAX_LEN", integer(), intl(64)),
      Parameter::Make("INDEX_WIDTH", integer(), intl(32)),
      Parameter::Make("CFG", string(), strl("")),
      Parameter::Make("CMD_TAG_ENABLE", boolean(), booll(true)),
      Parameter::Make("CMD_TAG_WIDTH", integer(), intl(1))});

  // Insert ports
  objects.insert(objects.end(), {
      Port::Make("bcd", cr(), Port::Dir::IN, bus_cd()),
      Port::Make("kcd", cr(), Port::Dir::IN, kernel_cd()),
      bus,
      Port::Make("cmd", cmd(intl(1), intl(1)), Port::Dir::IN, kernel_cd()),
      Port::Make("unl", unlock(), Port::Dir::OUT, kernel_cd()),
      data});

  auto ret = Component::Make(ArrayName(mode), objects);

  ret->SetMeta(cerata::vhdl::metakeys::PRIMITIVE, "true");
  ret->SetMeta(cerata::vhdl::metakeys::LIBRARY, "work");
  ret->SetMeta(cerata::vhdl::metakeys::PACKAGE, "Array_pkg");
  return ret;
}

std::unique_ptr<Instance> ArrayInstance(const std::string &name,
                                        fletcher::Mode mode,
                                        const std::shared_ptr<Node> &data_width,
                                        const std::shared_ptr<Node> &ctrl_width,
                                        const std::shared_ptr<Node> &tag_width) {
  std::unique_ptr<Instance> result;
  // Check if the Array component was already created.
  Component *array_component;
  auto optional_component = cerata::default_component_pool()->Get(ArrayName(mode));
  if (optional_component) {
    array_component = *optional_component;
  } else {
    array_component = Array(mode).get();
  }
  // Create and return an instance of the Array component.
  result = Instance::Make(array_component, name);
  return result;
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
    case arrow::Type::BOOL: return intl(1);
    case arrow::Type::DATE32: return intl(32);
    case arrow::Type::DATE64: return intl(64);
    case arrow::Type::DOUBLE: return intl(64);
    case arrow::Type::FLOAT: return intl(32);
    case arrow::Type::HALF_FLOAT: return intl(16);
    case arrow::Type::INT8: return intl(8);
    case arrow::Type::INT16: return intl(16);
    case arrow::Type::INT32: return intl(32);
    case arrow::Type::INT64: return intl(64);
    case arrow::Type::TIME32: return intl(32);
    case arrow::Type::TIME64: return intl(64);
    case arrow::Type::TIMESTAMP: return intl(64);
    case arrow::Type::UINT8: return intl(8);
    case arrow::Type::UINT16: return intl(16);
    case arrow::Type::UINT32: return intl(32);
    case arrow::Type::UINT64: return intl(64);

      // Lists:
    case arrow::Type::LIST: return strl("OFFSET_WIDTH");
    case arrow::Type::BINARY: return strl("OFFSET_WIDTH");
    case arrow::Type::STRING: return strl("OFFSET_WIDTH");

      // Others:
    default:
      // case arrow::Type::INTERVAL: return 0;
      // case arrow::Type::MAP: return 0;
      // case arrow::Type::NA: return 0;
      // case arrow::Type::DICTIONARY: return 0;
      // case arrow::Type::UNION: return 0;
      throw std::domain_error("Arrow type " + type->ToString() + " not supported.");

      // Structs have no width
    case arrow::Type::STRUCT: return intl(0);

      // Other width types:
    case arrow::Type::FIXED_SIZE_BINARY: {
      auto t = dynamic_cast<const arrow::FixedSizeBinaryType *>(type);
      return Literal::MakeInt(t->bit_width());
    }
    case arrow::Type::DECIMAL: {
      auto t = dynamic_cast<const arrow::DecimalType *>(type);
      return Literal::MakeInt(t->bit_width());
    }
  }
}

std::string GenerateConfigString(const arrow::Field &field, int level) {
  std::string ret;
  ConfigType ct = GetConfigType(field.type().get());

  if (field.nullable()) {
    ret += "null(";
    level++;
  }

  int epc = fletcher::GetIntMeta(field, metakeys::EPC, 1);
  int lepc = fletcher::GetIntMeta(field, metakeys::LEPC, 1);

  if (ct == ConfigType::PRIM) {
    auto w = GetWidth(field.type().get());
    ret += "prim(" + w->ToString();
    level++;
  } else if (ct == ConfigType::LISTPRIM) {
    ret += "listprim(8";
    level++;
  } else if (ct == ConfigType::LIST) {
    if (GetConfigType(field.type()->child(0)->type().get()) == ConfigType::PRIM) {
      ret += "list";
    } else {
      ret += "list(";
    }
    level++;
  } else if (ct == ConfigType::STRUCT) {
    ret += "struct(";
    level++;
  }

  if (epc > 1 || lepc > 1) {
    ret += ";";
  }
  if (epc > 1) {
    ret += "epc=" + std::to_string(epc);
    if (lepc > 1) {
      ret += ",";
    }
  }
  if (lepc > 1) {
    ret += "lepc=" + std::to_string(epc);
  }

  // Append children
  for (int c = 0; c < field.type()->num_children(); c++) {
    auto child = field.type()->child(c);
    ret += GenerateConfigString(*child);
    if (c != field.type()->num_children() - 1)
      ret += ",";
  }

  for (; level > 0; level--)
    ret += ")";

  return ret;
}

std::shared_ptr<TypeMapper> GetStreamTypeMapper(Type *stream_type, Type *other) {
  auto conversion = TypeMapper::Make(stream_type, other);

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

std::shared_ptr<Type> GetStreamType(const arrow::Field &field, fletcher::Mode mode, int level) {
  // The ordering of the record fields in this function determines the order in which a nested stream is type converted
  // automatically using GetStreamTypeConverter. This corresponds to how the hardware is implemented.
  //
  // WARNING: Modifications to this function must be reflected in the manual hardware implementation of Fletcher
  // components! See: hardware/arrays/ArrayConfig_pkg.vhd

  int epc = fletcher::GetIntMeta(field, metakeys::EPC, 1);
  int lepc = fletcher::GetIntMeta(field, metakeys::LEPC, 1);

  std::shared_ptr<Type> type;

  auto arrow_id = field.type()->id();
  const auto &name = field.name();

  switch (arrow_id) {
    case arrow::Type::BINARY: {
      // Special case: binary type has a length stream and byte stream. The EPC is assumed to relate to the list
      // values, as there is no explicit child field to place this metadata in.

      std::shared_ptr<Node> e_count_width = Literal::MakeInt(static_cast<int>(ceil(log2(epc + 1))));
      std::shared_ptr<Node> l_count_width = Literal::MakeInt(static_cast<int>(ceil(log2(lepc + 1))));
      std::shared_ptr<Node> data_width = Literal::MakeInt(epc * 8);
      std::shared_ptr<Node> length_width = Literal::MakeInt(lepc * 32);

      auto slave = Stream::Make(name,
                                Record::Make("slave_rec", {
                                    RecField::Make("dvalid", dvalid()),
                                    RecField::Make("last", last()),
                                    RecField::Make("data", data(data_width)),
                                    RecField::Make("count", count(e_count_width))
                                }), "", epc);
      type = Record::Make(name + "_rec", {
          RecField::Make("length", length(length_width)),
          RecField::Make("count", count(l_count_width)),
          RecField::Make("bytes", slave)
      });
      break;
    }

    case arrow::Type::STRING: {
      // Special case: string type has a length stream and utf8 character stream. The EPC is assumed to relate to the
      // list values, as there is no explicit child field to place this metadata in.

      std::shared_ptr<Node> e_count_width = Literal::MakeInt(static_cast<int>(ceil(log2(epc + 1))));
      std::shared_ptr<Node> l_count_width = Literal::MakeInt(static_cast<int>(ceil(log2(lepc + 1))));
      std::shared_ptr<Node> count_width = Literal::MakeInt(static_cast<int>(ceil(log2(epc + 1))));
      std::shared_ptr<Node> data_width = Literal::MakeInt(epc * 8);
      std::shared_ptr<Node> length_width = Literal::MakeInt(lepc * 32);

      auto slave = Stream::Make(name,
                                Record::Make("slave_rec", {
                                    RecField::Make("dvalid", dvalid()),
                                    RecField::Make("last", last()),
                                    RecField::Make("data", data(data_width)),
                                    RecField::Make("count", count(count_width))
                                }), "", epc);
      type = Record::Make(name + "_rec", {
          RecField::Make("length", length(length_width)),
          RecField::Make("count", count(l_count_width)),
          RecField::Make("chars", slave)
      });
      break;
    }

      // Lists
    case arrow::Type::LIST: {
      if (field.type()->num_children() != 1) {
        throw std::runtime_error("Encountered Arrow list type with other than 1 child.");
      }

      auto arrow_child = field.type()->child(0);
      auto element_type = GetStreamType(*arrow_child, mode, level + 1);
      std::shared_ptr<Node> length_width = Literal::MakeInt(32);

      auto slave = Stream::Make(name,
                                Record::Make("slave_rec", {
                                    RecField::Make("dvalid", dvalid()),
                                    RecField::Make("last", last()),
                                    RecField::Make("data", element_type)}),
                                "", epc);
      type = Record::Make(name + "_rec", {
          RecField::Make("length", length(length_width)),
          RecField::Make(arrow_child->name(), slave)
      });
      break;
    }

      // Structs
    case arrow::Type::STRUCT: {
      if (field.type()->num_children() < 1) {
        throw std::runtime_error("Encountered Arrow struct type without any children.");
      }
      std::deque<std::shared_ptr<RecField>> children;
      for (const auto &f : field.type()->children()) {
        auto child_type = GetStreamType(*f, mode, level + 1);
        children.push_back(RecField::Make(f->name(), child_type));
      }
      type = Record::Make(name + "_rec", children);
      break;
    }

      // Non-nested types
    default: {
      type = ConvertFixedWidthType(field.type());
      break;
    }
  }

  // If this is a top level field, create a stream out of it
  if (level == 0) {
    // Element name is empty by default.
    std::string elements_name;

    // Create the stream record
    auto record = Record::Make("data", {
        RecField::Make("dvalid", dvalid()),
        RecField::Make("last", last()),
        RecField::Make("", type)});
    if (field.nullable()) {
      record->AddField(RecField::Make("validity", validity()));
    }
    auto stream = Stream::Make(name, record);
    return stream;
  } else {
    // Otherwise just return the type
    return type;
  }
}

}  // namespace fletchgen
