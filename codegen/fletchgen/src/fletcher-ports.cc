#include <string>

#include "fletcher-ports.h"

#include "common.h"

using std::string;
using std::move;

using vhdl::nameFrom;
using vhdl::Value;

namespace fletchgen {

template<>
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
  throw std::runtime_error("Unknown port type.");
}

template<>
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
  throw std::runtime_error("Unknown port type.");
}

template<>
string typeToString(RRP type) {
  switch (type) {
    case RRP::VALID: return "valid";
    case RRP::READY: return "ready";
    case RRP::ADDRESS: return "addr";
    case RRP::BURSTLEN: return "len";;
  }
  throw std::runtime_error("Unknown port type.");
}

template<>
string typeToString(RDP type) {
  switch (type) {
    case RDP::VALID: return "valid";
    case RDP::READY: return "ready";
    case RDP::DATA: return "data";
    case RDP::LAST: return "last";
  }
  throw std::runtime_error("Unknown port type.");
}

template<>
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
  }
  throw std::runtime_error("Unknown port type.");
}

ASP mapUserTypeToColumnType(ASP type) {
  //todo make some static thing out of this
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

//TODO: do all of this in a smarter way:
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

}//namespace fletchgen