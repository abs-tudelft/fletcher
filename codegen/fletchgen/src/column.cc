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

#include <arrow/type.h>
#include <iostream>

#include "logging.h"
#include "vhdl/vhdl.h"
#include "common.h"
#include "stream.h"
#include "printers.h"
#include "column.h"

using vhdl::Generic;

namespace fletchgen {

Column::Column(const std::shared_ptr<arrow::Field> &field, Mode mode)
    : Instantiation(
    nameFrom({vhdl::makeIdentifier(field->name()), getModeString(mode), "inst"}),
    mode == Mode::READ ? "ColumnReader" : "ColumnWriter"
), mode_(mode), field_(field) {

  top_stream_ = getArrowStream(field);
  arrow_streams_ = flatten<ArrowStream>(top_stream_);

  auto buffers = getBuffers();
  auto num_buffers = (int) buffers.size();

  Value user_streams = Value(countArrowStreams());
  Value data_width = dataWidth();
  Value control_width = Value(ce::BUS_ADDR_WIDTH) * num_buffers;

  // Log the buffers
  auto infostr = "Buffers for [FIELD: " + field->ToString() + "]\n";
  for (auto &buf : buffers) {
    infostr += "  " + buf->name() + "\n";
  }
  infostr.pop_back();
  LOGD(infostr);

  // As a Column is an instantiation, select the proper component to use
  if (mode_ == Mode::READ) {
    comp_ = std::make_shared<ColumnReader>(this, user_streams, data_width, control_width);
  } else {
    throw std::runtime_error("ColumnWriter Not yet implemented.");
    //_comp = std::make_shared<ColumnWriter>();
  }

  // Create generic maps
  auto ent = comp_->entity();
  mapGeneric(ent->getGenericByName(ce::CONFIG_STRING), Value("\"" + configString() + "\""));

  mapGeneric(ent->getGenericByName(ce::BUS_ADDR_WIDTH), Value(ce::BUS_ADDR_WIDTH));
  mapGeneric(ent->getGenericByName(ce::BUS_LEN_WIDTH), Value(ce::BUS_LEN_WIDTH));
  mapGeneric(ent->getGenericByName(ce::BUS_DATA_WIDTH), Value(ce::BUS_DATA_WIDTH));
  mapGeneric(ent->getGenericByName(ce::BUS_BURST_STEP_LEN), Value(ce::BUS_BURST_STEP_LEN));
  mapGeneric(ent->getGenericByName(ce::BUS_BURST_MAX_LEN), Value(ce::BUS_BURST_MAX_LEN));
  mapGeneric(ent->getGenericByName(ce::INDEX_WIDTH), Value(ce::INDEX_WIDTH));
}

std::shared_ptr<ArrowStream> Column::getArrowStream(std::shared_ptr<arrow::Field> field,
                                                    ArrowStream *parent) {

  int epc = getEPC(field.get());

  LOGD(getFieldInfoString(field.get(), parent));

  if (field->type()->id() == arrow::Type::BINARY) {
    // Special case: binary type has a length stream and bytes stream.
    // The EPC is assumed to relate to the list elements, as there is no explicit child field to place this metadata in.
    auto master = std::make_shared<ArrowStream>(field, parent, mode_, ptr());
    auto slave = std::make_shared<ArrowStream>("bytes", Value(8), master.get(), mode_, ptr(), epc);
    master->addChild(slave);
    return master;
  } else if (field->type()->id() == arrow::Type::STRING) {
    // Special case: binary type has a length stream and bytes stream.
    // The EPC is assumed to relate to the list elements, as there is no explicit child field to place this metadata in.
    auto master = std::make_shared<ArrowStream>(field, parent, mode_, ptr());
    auto slave = std::make_shared<ArrowStream>("chars", Value(8), master.get(), mode_, ptr(), epc);
    master->addChild(slave);
    return master;
  } else {
    // Normal case: add a stream
    auto stream = std::make_shared<ArrowStream>(field, parent, mode_, ptr(), epc);
    //streams.push_back(stream);

    // Append any child streams for list or struct
    for (auto &child : field->type()->children()) {
      stream->addChild(getArrowStream(child, stream.get()));
    }
    return stream;
  }
}

std::shared_ptr<FletcherColumnStream> Column::generateUserCommandStream() {

  // Create the command stream.
  auto command = std::make_shared<CommandStream>(vhdl::makeIdentifier(field_->name()), ptr());

  // Create a vector to hold the ports for this stream.
  std::vector<std::shared_ptr<StreamPort>> ports;

  // Add command stream ports.
  ports.push_back(std::make_shared<CommandPort>("", CSP::VALID, Dir::IN, command.get()));
  ports.push_back(std::make_shared<CommandPort>("", CSP::READY, Dir::OUT, command.get()));
  ports.push_back(std::make_shared<CommandPort>("", CSP::FIRST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), command.get()));
  ports.push_back(std::make_shared<CommandPort>("", CSP::LAST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), command.get()));
  ports.push_back(std::make_shared<CommandPort>("", CSP::TAG, Dir::IN, Value(ce::TAG_WIDTH), command.get()));

  Value ctrl_offset(0);

  // For each buffer address, add a port.
  for (auto const &buffer: getBuffers()) {
    auto port = std::make_shared<CommandPort>(
        buffer->name(),
        CSP::ADDRESS,
        Dir::IN,
        Value(ce::BUS_ADDR_WIDTH),
        command.get(),
        ctrl_offset
    );
    //port->comment(t(2) + "-- Input for address of " + buffer + " buffer of field " + command->column()->field()->name() + ".\n");
    ports.push_back(port);
    ctrl_offset = ctrl_offset + Value(ce::BUS_ADDR_WIDTH);
  }

  command->addPort(ports);

  return command;
}

std::string Column::configString() {
  return genConfigString(field_.get());
}

int Column::countArrowStreams() {
  int count = 0;
  for (const auto &s: arrow_streams_) {
    if (!std::static_pointer_cast<ArrowStream>(s)->isStructChild()) {
      count++;
    }
  }
  return count;
}

std::vector<std::shared_ptr<Buffer>> Column::getBuffers() {
  std::vector<std::shared_ptr<Buffer>> buffers;
  for (const auto &s: arrow_streams_) {
    auto sbs = std::static_pointer_cast<ArrowStream>(s);
    auto bufs = sbs->getBuffers();
    buffers.insert(buffers.begin(), bufs.begin(), bufs.end());
  }
  return buffers;
}

Value Column::dataWidth() {
  Value ret;
  for (const auto &s: arrow_streams_) {
    auto as = std::static_pointer_cast<ArrowStream>(s);
    // Ports that are concatenated in the out_data port of a Column:
    auto ports = as->getPortsOfTypes({ASP::DATA, ASP::VALIDITY, ASP::LENGTH, ASP::COUNT});
    for (const auto &p: ports) {
      ret = ret + p->width();
    }
  }
  return ret;
}

std::string Column::toString() {
  return "[COLUMN INSTANCE: " + comp_->entity()->name() + " of field " + field_->ToString() + "]";
}

/**
 * Generate a ColumnReader
 */
ColumnReader::ColumnReader(Column *column, const Value &user_streams, const Value &data_width, Value &ctrl_width) :
    StreamComponent("ColumnReader"), DerivedFrom(column) {

  /* Generics */
  entity()
      ->addGeneric(std::make_shared<Generic>(ce::CONFIG_STRING, "string", Value("\"ERROR: CONFIG STRING NOT SET\"")));
  entity()->addGeneric(std::make_shared<Generic>(ce::BUS_ADDR_WIDTH, "natural", Value(64)));
  entity()->addGeneric(std::make_shared<Generic>(ce::BUS_LEN_WIDTH, "natural", Value(8)));
  entity()->addGeneric(std::make_shared<Generic>(ce::BUS_DATA_WIDTH, "natural", Value(512)));
  entity()->addGeneric(std::make_shared<Generic>(ce::BUS_BURST_STEP_LEN, "natural", Value(1)));
  entity()->addGeneric(std::make_shared<Generic>(ce::BUS_BURST_MAX_LEN, "natural", Value(64)));
  entity()->addGeneric(std::make_shared<Generic>(ce::INDEX_WIDTH, "natural", Value(32)));

  // Create the streams
  stream_cmd_ = std::make_shared<CommandStream>("", column);
  stream_rreq_ = std::make_shared<ReadRequestStream>("bus", column);
  stream_rdat_ = std::make_shared<ReadDataStream>("bus", column);
  stream_out_ = std::make_shared<FletcherColumnStream>("", FST::ARROW, column);

  stream_unl_ = std::make_shared<FletcherColumnStream>("", FST::UNLOCK, column);

  // Some port widths are "?". We only make maps to these ports, and their widths depend on the configuration string.

  entity()->addPort(std::make_shared<GeneralPort>(ce::BUS_CLK, GP::BUS_CLK, Dir::IN));
  entity()->addPort(std::make_shared<GeneralPort>(ce::BUS_RST, GP::BUS_RESET, Dir::IN));
  entity()->addPort(std::make_shared<GeneralPort>(ce::ACC_CLK, GP::ACC_CLK, Dir::IN));
  entity()->addPort(std::make_shared<GeneralPort>(ce::ACC_RST, GP::ACC_RESET, Dir::IN));

  /* Command stream */
  stream_cmd_->addPort(
      {std::make_shared<CommandPort>("", CSP::VALID, Dir::IN, stream_cmd_.get()),
       std::make_shared<CommandPort>("", CSP::READY, Dir::OUT, stream_cmd_.get()),
       std::make_shared<CommandPort>("", CSP::FIRST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), stream_cmd_.get()),
       std::make_shared<CommandPort>("", CSP::LAST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), stream_cmd_.get()),
       std::make_shared<CommandPort>("", CSP::CTRL, Dir::IN, ctrl_width, stream_cmd_.get()),
       std::make_shared<CommandPort>("", CSP::TAG, Dir::IN, Value(ce::TAG_WIDTH), stream_cmd_.get())
      }
  );

  // TODO: implement this
  /*
  unlock->addPort({std::make_shared<CommandPort>(Dir::OUT, ASP::VALID, unlock.get()),
                   std::make_shared<CommandPort>(Dir::IN, ASP::READY, unlock.get()),
                   std::make_shared<CommandPort>(Dir::OUT, Value("TAG_WIDTH"), ASP::TAG, unlock.get())
                  });
*/


  /* Read request channel */
  stream_rreq_->addPort(
      {std::make_shared<ReadReqPort>("", RRP::VALID, Dir::IN, stream_rreq_.get()),
       std::make_shared<ReadReqPort>("", RRP::READY, Dir::OUT, stream_rreq_.get()),
       std::make_shared<ReadReqPort>("", RRP::ADDRESS, Dir::IN, Value(ce::BUS_ADDR_WIDTH), stream_rreq_.get()),
       std::make_shared<ReadReqPort>("", RRP::BURSTLEN, Dir::IN, Value(ce::BUS_LEN_WIDTH), stream_rreq_.get())
      }
  );

  /* Read data channel */
  stream_rdat_->addPort(
      {std::make_shared<ReadDataPort>("", RDP::VALID, Dir::OUT, stream_rdat_.get()),
       std::make_shared<ReadDataPort>("", RDP::READY, Dir::IN, stream_rdat_.get()),
       std::make_shared<ReadDataPort>("", RDP::DATA, Dir::OUT, Value(ce::BUS_DATA_WIDTH), stream_rdat_.get()),
       std::make_shared<ReadDataPort>("", RDP::LAST, Dir::OUT, stream_rdat_.get())
      }
  );

  /* Output stream (to user core) */
  stream_out_->addPort(
      {std::make_shared<ArrowPort>("", ASP::VALID, Dir::OUT, user_streams, stream_out_.get()),
       std::make_shared<ArrowPort>("", ASP::READY, Dir::OUT, user_streams, stream_out_.get()),
       std::make_shared<ArrowPort>("", ASP::LAST, Dir::OUT, user_streams, stream_out_.get()),
       std::make_shared<ArrowPort>("", ASP::DATA, Dir::OUT, data_width, stream_out_.get()),
       std::make_shared<ArrowPort>("", ASP::DVALID, Dir::OUT, user_streams, stream_out_.get())
      }
  );

  appendStream(stream_cmd_);
  appendStream(stream_unl_);
  appendStream(stream_out_);
  appendStream(stream_rreq_);
  appendStream(stream_rdat_);

  addStreamPorts();
}

std::string Column::getColumnModeString(Mode mode) {
  if (mode == Mode::READ) {
    return "Reader";
  } else {
    return "Writer";
  }
}

}//namespace fletchgen