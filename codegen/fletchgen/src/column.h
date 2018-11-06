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

#include <arrow/type.h>

#include "./vhdl/vhdl.h"
#include "./common.h"
#include "arrow-meta.h"

#include "./fletcher-streams.h"

using vhdl::Instantiation;
using vhdl::nameFrom;

namespace fletchgen {

/**
 * @brief An instantiation of a Column(Reader/Writer) component
 */
class Column : public Instantiation {

 public:
  Column(const std::shared_ptr<arrow::Field> &field, Mode mode);

  /// @brief Convert a Mode to a string.
  static std::string getColumnModeString(Mode mode);

  /// @brief Return the Column(Reader/Writer) configuration string for this field that this Column can read/write.
  std::string configString();

  /// @brief Return the Arrow field from which this Column was generated.
  std::shared_ptr<arrow::Field> field() { return field_; }

  /// @brief Return the mode of this column (READ or WRITE).
  Mode mode() { return mode_; }

  /// @brief Return a human readable string with some info about this Column.
  std::string toString() override;

  Column *ptr() { return this; }

  /**
   * @brief Return a new ArrowStream based on a field.
   *
   * Typically, this will be a top-level schema field for which any children will be appended recursively as children of
   * the ArrowStream.
   * @param streams The vector of streams to append to.
   * @param field The field to generate streams from.
   * @param parent Parent stream used for recursive calls of this function.
   */
  std::shared_ptr<ArrowStream> getArrowStream(const std::shared_ptr<arrow::Field>& field,
                                              ArrowStream *parent = nullptr);

  /// @brief Generate the User Command Stream for this column.
  std::shared_ptr<FletcherColumnStream> generateUserCommandStream();

  /// @brief Return the user data streams that result from the field this column must read/write.
  std::vector<std::shared_ptr<ArrowStream>> getArrowStreams() { return arrow_streams_; }

  /// @brief number of Arrow streams, i.e. the number of valid/ready handshake signals on the Column output.
  int countArrowStreams();

  /// @brief The total with of the out_data port.
  Value dataWidth();

  /// @brief @return A vector of buffer names.
  std::vector<std::shared_ptr<Buffer>> getBuffers();

  /// @brief Return the name of this Column(Reader/Writer) instance.
  std::string name() override { return nameFrom({field_->name(), component()->entity()->name(), "inst"}); }

 private:
  Mode mode_ = Mode::READ;
  std::shared_ptr<arrow::Field> field_;
  std::shared_ptr<ArrowStream> top_stream_;
  std::vector<std::shared_ptr<ArrowStream>> arrow_streams_;
  std::string config_ = "";
};

/**
 * @brief A ColumnReader component
 */
struct ColumnReader : public StreamComponent, public DerivedFrom<Column> {
  ColumnReader(Column *column, const Value &user_streams, const Value &data_width, const Value &ctrl_width);

  std::shared_ptr<Stream> stream_cmd_;
  std::shared_ptr<Stream> stream_unl_;
  std::shared_ptr<Stream> stream_out_;
  std::shared_ptr<Stream> stream_rreq_;
  std::shared_ptr<Stream> stream_rdat_;
};

/**
 * @brief A ColumnWriter component
 */
/**
 * @brief A ColumnReader component
 */
struct ColumnWriter : public StreamComponent, public DerivedFrom<Column> {
  ColumnWriter(Column *column, const Value &user_streams, const Value &data_width, Value &ctrl_width);

  std::shared_ptr<Stream> stream_cmd_;
  std::shared_ptr<Stream> stream_unl_;
  std::shared_ptr<Stream> stream_in_;
  std::shared_ptr<Stream> stream_wreq_;
  std::shared_ptr<Stream> stream_wdat_;
};


/**
 * @brief Return the configuration string for an Arrow DataType.
 * @param field The DataType.
 * @return The configuration string.
 */
std::string genConfigString(const std::shared_ptr<arrow::Field>& field, int level = 0);

}//namespace fletchgen