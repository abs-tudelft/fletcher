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

#pragma once

#include <utility>
#include <vector>
#include <memory>

#include "./vhdl/vhdl.h"
#include "./stream.h"
#include "arrow-meta.h"
#include "./fletcher-ports.h"
#include "./common.h"

namespace fletchgen {

// Forward declarations
class Column;
class ReadArbiter;
class WriteArbiter;

/**
 * @brief Stream type enumeration for streams.
 */
enum class FST {
  CMD,      ///< Command stream
  RARROW,   ///< Arrow read data stream
  WARROW,   ///< Arrow read data stream
  RREQ,     ///< Bus read request channel
  RDAT,     ///< Bus read response channel
  WREQ,     ///< Bus write request channel
  WDAT,     ///< Bus write data channel
  UNLOCK    ///< Unlock stream
};

FST modeToArrowType(Mode mode);

/// @brief Convert Fletcher Stream Type to a string.
std::string typeToString(FST type);

/// @brief Convert Fletcher Stream Type to a longer string.
std::string typeToLongString(FST type);

//TODO: introduce the concept Sinks, Sources, and concatenated versions of each. And then route streams between them..?

/// @brief A Fletcher stream
class FletcherStream : public Stream, public TypedBy<FST> {
 public:
  FletcherStream(const std::string &name,
                 FST type,
                 std::vector<std::shared_ptr<StreamPort>> ports = {});

  explicit FletcherStream(FST type,
                          std::vector<std::shared_ptr<StreamPort>> ports = {});

  std::string toString() override;
};

/// @brief A Fletcher Stream that is derived from a Column
class FletcherColumnStream : public FletcherStream, public DerivedFrom<Column> {
 public:
  FletcherColumnStream(const std::string &name,
                       FST type,
                       Column *column,
                       std::vector<std::shared_ptr<StreamPort>> ports = {})
      : FletcherStream(name, type, std::move(ports)), DerivedFrom(column) {}

  FletcherColumnStream(FST type,
                       Column *column,
                       std::vector<std::shared_ptr<StreamPort>> ports = {})
      : FletcherStream(type, std::move(ports)), DerivedFrom(column) {}
};

/// @brief A column command stream.
class CommandStream : public FletcherColumnStream {
 public:
  CommandStream(const std::string &name,
                Column *column,
                std::vector<std::shared_ptr<StreamPort>> ports = {})
      : FletcherColumnStream(name, FST::CMD, column, std::move(ports)) {}
};

/// @brief A read request stream.
class ReadRequestStream
    : public FletcherStream, public DerivedFrom<vhdl::Instantiation>, public Destination<ReadArbiter> {
 public:
  explicit ReadRequestStream(const std::string &name,
                             vhdl::Instantiation *source = nullptr,
                             ReadArbiter *dest = nullptr,
                             std::vector<std::shared_ptr<StreamPort>> ports = {})
      : FletcherStream(name, FST::RREQ, std::move(ports)), DerivedFrom(source), Destination(dest) {}
};

/// @brief A read data stream.
class ReadDataStream
    : public FletcherStream, public DerivedFrom<vhdl::Instantiation>, public Destination<ReadArbiter> {
 public:
  explicit ReadDataStream(const std::string &name,
                          vhdl::Instantiation *source = nullptr,
                          ReadArbiter *dest = nullptr,
                          std::vector<std::shared_ptr<StreamPort>> ports = {})
      : FletcherStream(name, FST::RDAT, std::move(ports)), DerivedFrom(source), Destination(dest) {}
};

/// @brief A write request stream.
class WriteRequestStream
    : public FletcherStream, public DerivedFrom<vhdl::Instantiation>, public Destination<WriteArbiter> {
 public:
  explicit WriteRequestStream(const std::string &name,
                             vhdl::Instantiation *source = nullptr,
                             WriteArbiter *dest = nullptr,
                             std::vector<std::shared_ptr<StreamPort>> ports = {})
      : FletcherStream(name, FST::WREQ, std::move(ports)), DerivedFrom(source), Destination(dest) {}
};

/// @brief A write data stream.
class WriteDataStream
    : public FletcherStream, public DerivedFrom<vhdl::Instantiation>, public Destination<WriteArbiter> {
 public:
  explicit WriteDataStream(const std::string &name,
                          vhdl::Instantiation *source = nullptr,
                          WriteArbiter *dest = nullptr,
                          std::vector<std::shared_ptr<StreamPort>> ports = {})
      : FletcherStream(name, FST::WDAT, std::move(ports)), DerivedFrom(source), Destination(dest) {}
};


/// @brief A stream that delivers Arrow data
class ArrowStream : public FletcherColumnStream, public ChildOf<ArrowStream>, public ParentOf<ArrowStream> {
 public:
  /**
   * Construct a stream based on an Arrow field.
   * @param field The field to base the stream on.
   * @param parent The parent stream.
   * @param mode The stream "mode" (read or write)
   * @param epc The elements per cycle of the data items on this stream.
   */
  ArrowStream(std::shared_ptr<arrow::Field> field,
              ArrowStream *parent,
              Mode mode,
              Column *column,
              int epc = 1);

  /**
   * Construct a stream that is not based on an Arrow field directly. This is useful for lists types that don't have
   * explicit child fields, such as string, binary, etc...
   *
   * @param name The name of the stream.
   * @param width The width of the data items on this stream.
   * @param type The type of the stream
   * @param parent The parent stream.
   * @param mode The stream "mode" (read or write)
   * @param epc The elements per cycle of the data items on this stream.
   */
  ArrowStream(std::string name,
              Value width,
              ArrowStream *parent,
              Mode mode,
              Column *column,
              int epc = 1);

  /// @brief Return a human readable std::string with information about this stream.
  std::string toString() override;

  /// @brief Return the Arrow Field this stream was based on.
  std::shared_ptr<arrow::Field> field();

  /// @brief Return the hierarchical depth of this stream.
  int depth();

  /// @brief Return whether this stream is a list.
  bool isList();

  /// @brief Return whether this stream is a list child.
  bool isListChild();

  /// @brief Return whether this stream is a listprim child
  bool isListPrimChild();

  /// @brief Return whether this stream is a struct.
  bool isStruct();

  /// @brief Return whether this stream is a struct child.
  bool isStructChild();

  /// @brief Return whether this stream is nullable.
  bool isNullable();

  /// @brief Return the mode of this stream (read/write).
  Mode mode() { return mode_; }

  /// @brief Return the width of the ports of this stream by type.
  Value width(ASP type);

  /// @brief Return the width of the ports of this stream by a bunch of types.
  Value width(std::vector<ASP> types);

  /// @brief Change the number of elements per cycle that this stream should deliver.
  void setEPC(int epc);

  /// @brief Return whether this stream is based on an explicit Arrow field.
  bool basedOnField() { return field_ != nullptr; }

  /// @brief Return a vector containing all ports contained in \p types.
  std::vector<ArrowPort *> getPortsOfTypes(std::vector<ASP> types);

  ArrowStream *ptr() { return this; }

  /// @brief Return a prefix usable for signal names derived from field names in the schema.
  std::string getSchemaPrefix();

  /// @brief Return the names of the Arrow buffers that are required to generate this stream.
  std::vector<std::shared_ptr<Buffer>> getBuffers();

  /// @brief Return the offset on the concatenated data signal of the Column user data stream.
  Value data_offset();

  /// @brief Returns the offset on the concatenated control signals of the Column user data stream.
  Value control_offset();

  /// @brief Return the data offset for any following stream that is concatenated onto the same stream.
  Value next_data_offset();

  /// @brief Return the control offset for any following stream that is concatenated onto the same stream.
  Value next_control_offset();

 private:
  std::shared_ptr<arrow::Field> field_;
  Mode mode_;
  int epc_;
  std::vector<Buffer> buffers_;
  Value _address_offset;
};

}  // namespace fletchgen
