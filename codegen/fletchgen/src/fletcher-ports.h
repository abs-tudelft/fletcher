#pragma once

#include <string>

#include "stream.h"

namespace fletchgen {
/**
 * @brief Port type enumeration for Arrow stream ports.
 */
enum class ASP {
  VALID,       ///< Handshake valid signal.
  READY,       ///< Handshake ready signal.
  DATA,        ///< Data signal (usually a vector)
  DVALID,      ///< Dvalid for dealing with empty lists.
  LAST,        ///< Last signal for streams
  LENGTH,      ///< Length for a variable length item.
  VALIDITY,    ///< Validity bit from the validity bitmap (element is not null)
  COUNT,       ///< Count for listprim children.
};

/**
 * @brief Port type enumerations for command stream ports.
 */
enum class CSP {
  VALID,       ///< Handshake valid signal.
  READY,       ///< Handshake ready signal.
  FIRST_INDEX, ///< First index in a command stream.
  LAST_INDEX,  ///< Last index in a command stream.
  TAG,         ///< Tag in a command or unlock stream.
  ADDRESS,     ///< An address in host memory.
  CTRL,        ///< Control stream
};

/**
 * @brief Port type enumerations for read request ports.
 */
enum class RRP {
  VALID,       ///< Handshake valid signal.
  READY,       ///< Handshake ready signal.
  ADDRESS,     ///< An address in host memory.
  BURSTLEN,    ///< Bus burst length
};

/**
 * @brief Port type enumerations for read data ports.
 */
enum class RDP {
  VALID,       ///< Handshake valid signal.
  READY,       ///< Handshake ready signal.
  DATA,        ///< Read data
  LAST,        ///< Last transfer for bursts
};

/**
 * @brief Port type enumerations for write request ports.
 */
enum class WRP {
  VALID,       ///< Handshake valid signal.
  READY,       ///< Handshake ready signal.
  ADDRESS,     ///< An address in host memory.
  BURSTLEN,    ///< Bus burst length
};


/**
 * @brief Port type enumerations for write data ports.
 */
enum class WDP {
  VALID,       ///< Handshake valid signal.
  READY,       ///< Handshake ready signal.
  DATA,        ///< Write data
  STROBE,      ///< Write strobe
  LAST,        ///< Last transfer for bursts
};

/**
 * @brief Port type enumeration for generic ports (not stream ports).
 */
enum class GP {
  BUS_CLK,     ///< Bus clock
  BUS_RESET,   ///< Bus reset
  ACC_CLK,     ///< Accelerator clock
  ACC_RESET,   ///< Accelerator reset
  REG,         ///< Generic register
  REG_STATUS,  ///< Status register
  REG_CONTROL, ///< Control register
  REG_ADDR,    ///< Address regiser
  REG_USER,    ///< User registers
  REG_RETURN,  ///< Return register
  REG_IDX,     ///< Row index register
  SIG,         ///< Other signals
};

std::string typeToString(ASP type);
std::string typeToString(CSP type);
std::string typeToString(GP type);
std::string typeToString(RDP type);
std::string typeToString(WDP type);
std::string typeToString(RRP type);
std::string typeToString(WRP type);

ASP mapUserTypeToColumnType(ASP type);
CSP mapUserTypeToColumnType(CSP type);

/**
 * @brief Arrow Stream Port
 *
 * A port that belongs to an Arrow stream.
 */
class ArrowPort : public StreamPort, public TypedBy<ASP>, public WithOffset {
 public:
  ArrowPort(const std::string &name, ASP type, Dir dir, const Value &width, Stream *stream, Value offset = Value(0));

  ArrowPort(const std::string &name, ASP type, Dir dir, Stream *stream, Value offset = Value(0));
};

///@brief Command Stream Port
class CommandPort : public StreamPort, public TypedBy<CSP>, public WithOffset {
 public:
  CommandPort(const std::string &name, CSP type, Dir dir, const Value &width, Stream *stream, Value offset = Value(0));

  CommandPort(const std::string &name, CSP type, Dir dir, Stream *stream, Value offset = Value(0));
};

/// @brief Read Request Stream Port
class ReadReqPort : public StreamPort, public TypedBy<RRP>, public WithOffset {
 public:
  ReadReqPort(const std::string &name,
              RRP type,
              Dir dir,
              const Value &width,
              Stream *stream,
              Value offset = Value(0));

  ReadReqPort(const std::string &name, RRP type, Dir dir, Stream *stream, Value offset = Value(0));
};

/// @brief Read Data Port
class ReadDataPort : public StreamPort, public TypedBy<RDP>, public WithOffset {
 public:
  ReadDataPort(const std::string &name, RDP type, Dir dir, const Value &width, Stream *stream, Value offset = Value(0));

  ReadDataPort(const std::string &name, RDP type, Dir dir, Stream *stream, Value offset = Value(0));
};

/// @brief Write Request Stream Port
class WriteReqPort : public StreamPort, public TypedBy<WRP>, public WithOffset {
 public:
  WriteReqPort(const std::string &name,
              WRP type,
              Dir dir,
              const Value &width,
              Stream *stream,
              Value offset = Value(0));

  WriteReqPort(const std::string &name, WRP type, Dir dir, Stream *stream, Value offset = Value(0));
};

/// @brief Read Data Port
class WriteDataPort : public StreamPort, public TypedBy<WDP>, public WithOffset {
 public:
  WriteDataPort(const std::string &name, WDP type, Dir dir, const Value &width, Stream *stream, Value offset = Value(0));

  WriteDataPort(const std::string &name, WDP type, Dir dir, Stream *stream, Value offset = Value(0));
};

/**
 * @brief Fletcher General Ports
 *
 * Fletcher ports which are not part of a stream. They are generic ports, but to avoid confusion with the VHDL term
 * "generic", we call them general ports.
 */
class GeneralPort : public Port, public TypedBy<GP> {
 public:
  GeneralPort(std::string name, GP type, Dir direction, Value width) :
      Port(std::move(name), direction, std::move(width)), TypedBy(type) {};

  GeneralPort(std::string name, GP type, Dir direction) :
      Port(std::move(name), direction), TypedBy(type) {};
};

}
