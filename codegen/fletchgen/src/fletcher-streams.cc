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

#include <arrow/type.h>

#include "./fletcher-streams.h"

using std::shared_ptr;
using std::vector;
using std::move;
using std::make_shared;
using std::string;

using vhdl::nameFrom;

namespace fletchgen {

string typeToString(FST type) {
  switch (type) {
    case FST::CMD: return "cmd";
    case FST::RARROW: return "out";
    case FST::WARROW: return "in";
    case FST::UNLOCK: return "unl";
    case FST::RREQ: return "rreq";
    case FST::RDAT: return "rdat";
    case FST::WREQ: return "wreq";
    case FST::WDAT: return "wdat";
  }
  throw std::runtime_error("Unkown type.");
}

string typeToLongString(FST type) {
  switch (type) {
    case FST::CMD: return "COMMAND";
    case FST::RARROW: return "READ DATA";
    case FST::WARROW: return "WRITE DATA";
    case FST::UNLOCK: return "UNLOCK";
    case FST::RREQ: return "BUS READ REQUEST";
    case FST::RDAT: return "BUS READ RESPONSE";
    case FST::WREQ: return "BUS WRITE REQUEST";
    case FST::WDAT: return "BUS WRITE RESPONSE";
  }
  throw std::runtime_error("Unkown type.");
}

FST modeToArrowType(Mode mode) {
  if (mode == Mode::READ) {
    return FST::RARROW;
  } else {
    return FST::WARROW;
  }
}

vector<shared_ptr<Buffer>> ArrowStream::getBuffers() {
  vector<shared_ptr<Buffer>> ret;
  if (basedOnField()) {
    // If the field is nullable, append a validity buffer
    if (field()->nullable()) {
      ret.push_back(make_shared<Buffer>(nameFrom({getSchemaPrefix(), "validity"})));
    }
    // Lists add an offsets buffer.
    if ((field()->type()->id() == arrow::Type::LIST) || (field()->type()->id() == arrow::Type::BINARY)
        || (field()->type()->id() == arrow::Type::STRING)) {
      ret.push_back(make_shared<Buffer>(nameFrom({getSchemaPrefix(), "offsets"})));
    }
      // If it's not a list, and not a struct, there is always a values buffer.
    else if ((field()->type()->id() != arrow::Type::STRUCT)) {
      ret.push_back(make_shared<Buffer>(nameFrom({getSchemaPrefix(), "values"})));
    }
  } else {
    if (hasParent()) {
      if (parent()->basedOnField()) {
        if (parent()->field()->type()->id() == arrow::Type::STRING) {
          //TODO: temporarily leave this madness here in case we want to change it to "chars" and "bytes"
          ret.push_back(make_shared<Buffer>(nameFrom({getSchemaPrefix(), "values"})));
        } else if (parent()->field()->type()->id() == arrow::Type::BINARY) {
          ret.push_back(make_shared<Buffer>(nameFrom({getSchemaPrefix(), "values"})));
        }
      }
    }
  }
  return ret;
}

vector<ArrowPort *> ArrowStream::getPortsOfTypes(vector<ASP> types) {
  vector<ArrowPort *> sps;
  for (const auto &p : ports()) {
    auto sp = dynamic_cast<ArrowPort *>(p.get());
    if (sp != nullptr)
      for (const auto &t : types) {
        if (sp->type() == t) {
          sps.emplace_back(sp);
        }
      }
  }
  return sps;
}

ArrowStream::ArrowStream(shared_ptr<arrow::Field> field, ArrowStream *parent, Mode mode, Column *column, int epc)
    : FletcherColumnStream(parent != nullptr ?
                           nameFrom({parent->name(), vhdl::makeIdentifier(field->name())})
                                             : vhdl::makeIdentifier(field->name()),
                           modeToArrowType(mode),
                           column),
      ChildOf(parent),
      field_(move(field)),
      mode_(mode),
      epc_(epc) {

  // Determine port direction from stream mode.
  Dir dir = mode_ == Mode::READ ? Dir::OUT : Dir::IN;

  Value data_offset(0);
  Value control_offset(0);

  if (hasParent()) {
    data_offset = parent->next_data_offset();
    control_offset = parent->next_control_offset();
  }

  // Add valid, ready and last signals if parent is not a struct
  if (!isStructChild()) {
    addPort(make_shared<ArrowPort>("", ASP::VALID, dir, ptr(), control_offset));
    addPort(make_shared<ArrowPort>("", ASP::READY, rev(dir), ptr(), control_offset));
    addPort(make_shared<ArrowPort>("", ASP::LAST, dir, ptr(), control_offset));
  }

  if (isListChild()) {
    addPort(make_shared<ArrowPort>("", ASP::DVALID, dir, ptr(), control_offset));
  }

  // Add validity bit if its nullable
  if (isNullable()) {
    addPort(make_shared<ArrowPort>("", ASP::VALIDITY, dir, ptr(), data_offset));
    data_offset = data_offset + Value(1);
  }

  // Add data ports if this is not a struct
  if (!isStruct()) {
    Value width = getWidth(field_->type().get());
    if (!isList()) {
      // Add the data port
      addPort(make_shared<ArrowPort>("", ASP::DATA, dir, width * epc_, ptr(), data_offset));
      data_offset = data_offset + (width * epc_);

      // Only add a count port if this is a listprim secondary stream
      if (isListPrimChild()) {
        addPort(make_shared<ArrowPort>("", ASP::COUNT, dir, Value(vhdl::log2ceil(epc_ + 1)), ptr(), data_offset));
        data_offset += 1;
      }
    } else {
      // If this is a list, the data port is a length
      addPort(make_shared<ArrowPort>("", ASP::LENGTH, dir, width * epc_, ptr(), data_offset));
    }
  }
}

ArrowStream::ArrowStream(string name, Value width, ArrowStream *parent, Mode mode, Column *column, int epc)
    : FletcherColumnStream(parent != nullptr ? nameFrom({parent->name(), name}) : name, modeToArrowType(mode), column),
      ChildOf(parent),
      field_(nullptr),
      mode_(mode),
      epc_(epc) {
  // Determine port direction from stream mode.
  Dir dir = mode_ == Mode::READ ? Dir::OUT : Dir::IN;

  Value data_offset(0);
  Value control_offset(0);

  if (hasParent()) {
    data_offset = parent->next_data_offset();
    control_offset = parent->next_control_offset();
  }

  addPort(make_shared<ArrowPort>("", ASP::VALID, dir, ptr(), control_offset));
  addPort(make_shared<ArrowPort>("", ASP::READY, rev(dir), ptr(), control_offset));
  addPort(make_shared<ArrowPort>("", ASP::LAST, dir, ptr(), control_offset));

  // This is probably always true, otherwise there is no reason to construct an Arrow Stream not based on an explicit
  // field.
  if (isListChild()) {
    addPort(make_shared<ArrowPort>("", ASP::DVALID, dir, ptr(), control_offset));
  }

  // Add validity bit if its nullable
  if (isNullable()) {
    addPort(make_shared<ArrowPort>("", ASP::VALIDITY, dir, ptr(), data_offset));
    data_offset += 1;
  }

  // Add data port. We don't have to check for struct or list because they must always have a child. A string and a
  // width parameter do not expose a child like an arrow::Field could.
  addPort(make_shared<ArrowPort>("", ASP::DATA, dir, width * epc_, ptr(), data_offset));
  data_offset = data_offset + width * epc_;

  // Add a count port if this is a listprim secondary stream
  if (isListPrimChild()) {
    addPort(make_shared<ArrowPort>("", ASP::COUNT, dir, Value(vhdl::log2ceil(epc_ + 1)), ptr(), data_offset));
    data_offset += 1;
  }

}

int ArrowStream::depth() {
  int d = 0;
  auto s = this;
  while (s->hasParent()) {
    s = s->parent();
    d++;
  }
  return d;
}

bool ArrowStream::isList() {
  bool ret = false;
  ret |= field_->type()->id() == arrow::Type::LIST;
  ret |= field_->type()->id() == arrow::Type::STRING;
  ret |= field_->type()->id() == arrow::Type::BINARY;
  return ret;
}

bool ArrowStream::isNullable() {
  if (field_ != nullptr) {
    return field_->nullable();
  } else {
    return false;
  }
}

bool ArrowStream::isStruct() {
  if (field_ != nullptr) {
    return field_->type()->id() == arrow::Type::STRUCT;
  } else {
    return false;
  }
}

bool ArrowStream::isListPrimChild() {
  bool ret = false;
  // For now, basedOnField is only true for string and binary.
  if (!basedOnField()) {
    return true;
  }
  return ret;
}

bool ArrowStream::isListChild() { return hasParent() ? parent()->isList() : false; }

bool ArrowStream::isStructChild() { return hasParent() ? parent()->isStruct() : false; }

shared_ptr<arrow::Field> ArrowStream::field() { return field_; }

void ArrowStream::setEPC(int epc) {
  if (epc_ > 0) {
    epc_ = epc;
  } else {
    throw std::domain_error("Elements per cycle must be a positive non-zero value.");
  }
}

Value ArrowStream::width(ASP type) {
  Value w = Value(0);
  for (const auto &p : ports()) {
    auto ap = castOrThrow<ArrowPort>(p.get());
    if (ap->type() == type) {
      w = w + p->width();
    }
  }
  return w;
}

Value ArrowStream::width(vector<ASP> types) {
  Value w = Value(0);
  for (auto &p : ports()) {
    auto ap = castOrThrow<ArrowPort>(p.get());
    for (auto &t: types) {
      if (ap->type() == t) {
        w = w + p->width();
      }
    }
  }
  return w;
}

Value ArrowStream::data_offset() {
  Value ret;
  auto root = rootOf<ArrowStream>(this);
  auto flat_streams = flatten<ArrowStream>(root);
  for (const auto &s : flat_streams) {
    if (s != this) {
      ret = ret + s->width({ASP::DATA, ASP::COUNT, ASP::VALIDITY, ASP::LENGTH});
    } else {
      break;
    }
  }
  return ret;
}

Value ArrowStream::next_data_offset() {
  return data_offset() + width({ASP::DATA, ASP::COUNT, ASP::VALIDITY, ASP::LENGTH});
}

Value ArrowStream::control_offset() {
  Value ret;
  auto root = rootOf<ArrowStream>(this);
  auto flat_streams = flatten<ArrowStream>(root);
  for (const auto &s : flat_streams) {
    if (s != this) {
      ret = ret + Value(1);
    } else {
      break;
    }
  }
  return ret;
}

Value ArrowStream::next_control_offset() {
  return control_offset() + Value(1);
}

std::string ArrowStream::getSchemaPrefix() {
  std::string ret;
  if (hasParent()) {
    ret = parent()->getSchemaPrefix();
  }
  if (basedOnField()) {
    ret = nameFrom({ret, vhdl::makeIdentifier(field()->name())});
  }
  return ret;
}

std::string ArrowStream::toString() {
  return "[" + typeToLongString(type()) + " STREAM: " + name()
         + (hasParent() ? " | parent: " + parent()->toString() : "")
         + "| ports: " + std::to_string(ports().size()) + "]";
}

FletcherStream::FletcherStream(const string &name, FST type, vector<shared_ptr<StreamPort>> ports)
    : Stream(nameFrom({name, typeToString(type)}), move(ports)), TypedBy(type) {}

FletcherStream::FletcherStream(FST type, vector<shared_ptr<StreamPort>> ports)
    : Stream(typeToString(type), move(ports)), TypedBy(type) {}

std::string FletcherStream::toString() {
  return "[" + typeToLongString(type()) + " STREAM: " + name() + " | ports: " + std::to_string(ports().size()) + "]";
}

}