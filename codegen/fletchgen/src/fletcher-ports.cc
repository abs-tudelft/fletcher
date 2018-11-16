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

#include <string>

#include "./fletcher-ports.h"
#include "./constants.h"

using std::string;
using std::move;

using vhdl::nameFrom;
using vhdl::Value;

namespace fletchgen {

string typeToString(ASP type) {
  switch (type) {
    case ASP::VALID: return "valid";
    case ASP::READY: return "ready";
    case ASP::LENGTH: return "length";
    case ASP::VALIDITY: return "validity";
    case ASP::DATA: return "data";
    case ASP::LAST: return "last";
    case ASP::DVALID: return "dvalid";
    case ASP::COUNT: return "count";
  }
  throw std::runtime_error("Unkown type.");
}

string typeToString(CSP type) {
  switch (type) {
    case CSP::FIRST_INDEX: return "firstIdx";
    case CSP::LAST_INDEX: return "lastIdx";
    case CSP::TAG: return "tag";
    case CSP::ADDRESS: return "addr";
    case CSP::CTRL: return "ctrl";
    case CSP::VALID: return "valid";
    case CSP::READY: return "ready";
  }
  throw std::runtime_error("Unkown type.");
}

string typeToString(USP type) {
  switch (type) {
    case USP::VALID: return "valid";
    case USP::READY: return "ready";
    case USP::TAG: return "tag";
  }
  throw std::runtime_error("Unkown type.");
}

string typeToString(GP type) {
  switch (type) {
    case GP::BUS_CLK:return ce::BUS_CLK;
    case GP::BUS_RESET:return ce::BUS_RST;
    case GP::ACC_CLK:return ce::ACC_CLK;
    case GP::ACC_RESET:return ce::ACC_RST;
    case GP::REG_ADDR:return "reg_arrow_buf_addr";
    case GP::REG:return "reg";
    case GP::REG_STATUS:return "reg_status";
    case GP::REG_CONTROL:return "reg_control";
    case GP::REG_USER:return "reg_user";
    case GP::SIG:return "signal";
    case GP::REG_RETURN:return "reg_return";
    case GP::REG_IDX:return "reg_idx";
  }
  throw std::runtime_error("Unkown type.");
}

string typeToString(RRP type) {
  switch (type) {
    case RRP::VALID: return "valid";
    case RRP::READY: return "ready";
    case RRP::ADDRESS: return "addr";
    case RRP::BURSTLEN: return "len";;
  }
  throw std::runtime_error("Unkown type.");
}

string typeToString(RDP type) {
  switch (type) {
    case RDP::VALID: return "valid";
    case RDP::READY: return "ready";
    case RDP::DATA: return "data";
    case RDP::LAST: return "last";
  }
  throw std::runtime_error("Unkown type.");
}

string typeToString(WDP type) {
  switch (type) {
    case WDP::VALID: return "valid";
    case WDP::READY: return "ready";
    case WDP::DATA: return "data";
    case WDP::STROBE: return "strobe";
    case WDP::LAST: return "last";
  }
  throw std::runtime_error("Unkown type.");
}

string typeToString(WRP type) {
  switch (type) {
    case WRP::VALID: return "valid";
    case WRP::READY: return "ready";
    case WRP::ADDRESS: return "addr";
    case WRP::BURSTLEN: return "len";;
  }
  throw std::runtime_error("Unkown type.");
}

ASP mapUserTypeToColumnType(ASP type) {
  // TODO(johanpel): make some static thing out of this
  std::map<ASP, ASP> mapping({std::pair<ASP, ASP>(ASP::VALID, ASP::VALID),
                              std::pair<ASP, ASP>(ASP::READY, ASP::READY),
                              std::pair<ASP, ASP>(ASP::DATA, ASP::DATA),
                              std::pair<ASP, ASP>(ASP::LAST, ASP::LAST),
                              std::pair<ASP, ASP>(ASP::DVALID, ASP::DVALID),
                              std::pair<ASP, ASP>(ASP::LENGTH, ASP::DATA),
                              std::pair<ASP, ASP>(ASP::VALIDITY, ASP::DATA),
                              std::pair<ASP, ASP>(ASP::COUNT, ASP::DATA)
                             });
  return mapping[type];
}

CSP mapUserTypeToColumnType(CSP type) {
  std::map<CSP, CSP> mapping({std::pair<CSP, CSP>(CSP::CTRL, CSP::CTRL),
                              std::pair<CSP, CSP>(CSP::FIRST_INDEX, CSP::FIRST_INDEX),
                              std::pair<CSP, CSP>(CSP::LAST_INDEX, CSP::LAST_INDEX),
                              std::pair<CSP, CSP>(CSP::TAG, CSP::TAG),
                              std::pair<CSP, CSP>(CSP::ADDRESS, CSP::CTRL),
                              std::pair<CSP, CSP>(CSP::VALID, CSP::VALID),
                              std::pair<CSP, CSP>(CSP::READY, CSP::READY)
                             });
  return mapping[type];
}

// TODO(johanpel): do all of this in a smarter way:
ArrowPort::ArrowPort(const std::string &name, ASP type, Dir dir, const Value &width, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, width, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

ArrowPort::ArrowPort(const std::string &name, ASP type, Dir dir, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

CommandPort::CommandPort(const std::string &name, CSP type, Dir dir, const Value &width, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, width, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

CommandPort::CommandPort(const std::string &name, CSP type, Dir dir, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

UnlockPort::UnlockPort(const std::string &name, USP type, Dir dir, const Value &width, Stream *stream)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, width, stream), TypedBy(type) {}

UnlockPort::UnlockPort(const std::string &name, USP type, Dir dir, Stream *stream)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, stream), TypedBy(type) {}

ReadReqPort::ReadReqPort(const std::string &name, RRP type, Dir dir, const Value &width, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, width, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

ReadReqPort::ReadReqPort(const std::string &name, RRP type, Dir dir, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

ReadDataPort::ReadDataPort(const std::string &name, RDP type, Dir dir, const Value &width, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, width, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

ReadDataPort::ReadDataPort(const std::string &name, RDP type, Dir dir, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

WriteReqPort::WriteReqPort(const std::string &name, WRP type, Dir dir, const Value &width, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, width, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

WriteReqPort::WriteReqPort(const std::string &name, WRP type, Dir dir, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

WriteDataPort::WriteDataPort(const std::string &name,
                             WDP type,
                             Dir dir,
                             const Value &width,
                             Stream *stream,
                             Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, width, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

WriteDataPort::WriteDataPort(const std::string &name, WDP type, Dir dir, Stream *stream, Value offset)
    : StreamPort(nameFrom({stream->name(), name, typeToString(type)}), dir, stream),
      TypedBy(type),
      WithOffset(std::move(offset)) {}

}  // namespace fletchgen
