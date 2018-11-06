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
#include <string>
#include <vector>

#include <arrow/type.h>

#include "./arrow-meta.h"
#include "./logging.h"
#include "./vhdl/vhdl.h"
#include "./common.h"
#include "./stream.h"
#include "./printers.h"
#include "./column.h"

using vhdl::Generic;
using std::make_shared;

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
    comp_ = make_shared<ColumnReader>(this, user_streams, data_width, control_width);
  } else {
    comp_ = make_shared<ColumnWriter>(this, user_streams, data_width, control_width);
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

  // Generics for columnwriters only
  if (mode == Mode::WRITE) {
    mapGeneric(ent->getGenericByName(ce::BUS_STROBE_WIDTH), Value(ce::BUS_STROBE_WIDTH));
  }
}

std::shared_ptr<ArrowStream> Column::getArrowStream(const std::shared_ptr<arrow::Field>& field, ArrowStream *parent) {
  int epc = fletcher::getEPC(field);

  LOGD(getFieldInfoString(field, parent));

  if (field->type()->id() == arrow::Type::BINARY) {
    // Special case: binary type has a length stream and bytes stream.
    // The EPC is assumed to relate to the list elements, as there is no explicit child field to place this metadata in.
    auto master = make_shared<ArrowStream>(field, parent, mode_, ptr());
    auto slave = make_shared<ArrowStream>("bytes", Value(8), master.get(), mode_, ptr(), epc);
    master->addChild(slave);
    return master;
  } else if (field->type()->id() == arrow::Type::STRING) {
    // Special case: binary type has a length stream and bytes stream.
    // The EPC is assumed to relate to the list elements, as there is no explicit child field to place this metadata in.
    auto master = make_shared<ArrowStream>(field, parent, mode_, ptr());
    auto slave = make_shared<ArrowStream>("chars", Value(8), master.get(), mode_, ptr(), epc);
    master->addChild(slave);
    return master;
  } else {
    // Normal case: add a stream
    auto stream = make_shared<ArrowStream>(field, parent, mode_, ptr(), epc);

    // Append any child streams for list or struct
    for (auto &child : field->type()->children()) {
      stream->addChild(getArrowStream(child, stream.get()));
    }
    return stream;
  }
}

std::shared_ptr<FletcherColumnStream> Column::generateUserCommandStream() {
  // Create the command stream.
  auto command = make_shared<CommandStream>(vhdl::makeIdentifier(field_->name()), ptr());

  // Create a vector to hold the ports for this stream.
  std::vector<std::shared_ptr<StreamPort>> ports;

  // Add command stream ports.
  ports.push_back(make_shared<CommandPort>("", CSP::VALID, Dir::IN, command.get()));
  ports.push_back(make_shared<CommandPort>("", CSP::READY, Dir::OUT, command.get()));
  ports.push_back(make_shared<CommandPort>("", CSP::FIRST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), command.get()));
  ports.push_back(make_shared<CommandPort>("", CSP::LAST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), command.get()));
  ports.push_back(make_shared<CommandPort>("", CSP::TAG, Dir::IN, Value(ce::TAG_WIDTH), command.get()));

  Value ctrl_offset(0);

  // For each buffer address, add a port.
  for (auto const &buffer : getBuffers()) {
    auto port = make_shared<CommandPort>(
        buffer->name(),
        CSP::ADDRESS,
        Dir::IN,
        Value(ce::BUS_ADDR_WIDTH),
        command.get(),
        ctrl_offset);
    ports.push_back(port);
    ctrl_offset = ctrl_offset + Value(ce::BUS_ADDR_WIDTH);
  }

  command->addPort(ports);

  return command;
}

std::string Column::configString() {
  return genConfigString(field_);
}

int Column::countArrowStreams() {
  int count = 0;
  for (const auto &s : arrow_streams_) {
    if (!std::static_pointer_cast<ArrowStream>(s)->isStructChild()) {
      count++;
    }
  }
  return count;
}

std::vector<std::shared_ptr<Buffer>> Column::getBuffers() {
  std::vector<std::shared_ptr<Buffer>> buffers;
  for (const auto &s : arrow_streams_) {
    auto sbs = std::static_pointer_cast<ArrowStream>(s);
    auto bufs = sbs->getBuffers();
    buffers.insert(buffers.begin(), bufs.begin(), bufs.end());
  }
  return buffers;
}

Value Column::dataWidth() {
  Value ret;
  for (const auto &s : arrow_streams_) {
    auto as = std::static_pointer_cast<ArrowStream>(s);
    // Ports that are concatenated in the out_data port of a Column:
    auto ports = as->getPortsOfTypes({ASP::DATA, ASP::VALIDITY, ASP::LENGTH, ASP::COUNT});
    for (const auto &p : ports) {
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
ColumnReader::ColumnReader(Column *column, const Value &user_streams, const Value &data_width, const Value &ctrl_width) :
    StreamComponent("ColumnReader"), DerivedFrom(column) {
  /* Generics */
  entity()
      ->addGeneric(make_shared<Generic>(ce::CONFIG_STRING, "string", Value("\"ERROR: CONFIG STRING NOT SET\"")));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_ADDR_WIDTH, "natural", Value(ce::BUS_ADDR_WIDTH_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_LEN_WIDTH, "natural", Value(ce::BUS_LEN_WIDTH_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_DATA_WIDTH, "natural", Value(ce::BUS_DATA_WIDTH_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_BURST_STEP_LEN, "natural", Value(ce::BUS_BURST_STEP_LEN_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_BURST_MAX_LEN, "natural", Value(ce::BUS_BURST_MAX_LEN_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::INDEX_WIDTH, "natural", Value(ce::INDEX_WIDTH_DEFAULT)));

  // Create the streams
  stream_cmd_ = make_shared<CommandStream>("", column);
  stream_rreq_ = make_shared<ReadRequestStream>("bus", column);
  stream_rdat_ = make_shared<ReadDataStream>("bus", column);
  stream_out_ = make_shared<FletcherColumnStream>("", FST::RARROW, column);

  stream_unl_ = make_shared<FletcherColumnStream>("", FST::UNLOCK, column);

  // Some port widths are "?". We only make maps to these ports, and their widths depend on the configuration string.

  entity()->addPort(make_shared<GeneralPort>(ce::BUS_CLK, GP::BUS_CLK, Dir::IN));
  entity()->addPort(make_shared<GeneralPort>(ce::BUS_RST, GP::BUS_RESET, Dir::IN));
  entity()->addPort(make_shared<GeneralPort>(ce::ACC_CLK, GP::ACC_CLK, Dir::IN));
  entity()->addPort(make_shared<GeneralPort>(ce::ACC_RST, GP::ACC_RESET, Dir::IN));

  /* Command stream */
  stream_cmd_->addPort(
      {make_shared<CommandPort>("", CSP::VALID, Dir::IN, stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::READY, Dir::OUT, stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::FIRST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::LAST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::CTRL, Dir::IN, ctrl_width, stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::TAG, Dir::IN, Value(ce::TAG_WIDTH), stream_cmd_.get())
      });

  // TODO(johanpel): implement unlock stream
  /*
  unlock->addPort({make_shared<CommandPort>(Dir::OUT, ASP::VALID, unlock.get()),
                   make_shared<CommandPort>(Dir::IN, ASP::READY, unlock.get()),
                   make_shared<CommandPort>(Dir::OUT, Value("TAG_WIDTH"), ASP::TAG, unlock.get())
                  });
*/

  /* Read request channel */
  stream_rreq_->addPort(
      {make_shared<ReadReqPort>("", RRP::VALID, Dir::IN, stream_rreq_.get()),
       make_shared<ReadReqPort>("", RRP::READY, Dir::OUT, stream_rreq_.get()),
       make_shared<ReadReqPort>("", RRP::ADDRESS, Dir::IN, Value(ce::BUS_ADDR_WIDTH), stream_rreq_.get()),
       make_shared<ReadReqPort>("", RRP::BURSTLEN, Dir::IN, Value(ce::BUS_LEN_WIDTH), stream_rreq_.get())
      });

  /* Read data channel */
  stream_rdat_->addPort(
      {make_shared<ReadDataPort>("", RDP::VALID, Dir::OUT, stream_rdat_.get()),
       make_shared<ReadDataPort>("", RDP::READY, Dir::IN, stream_rdat_.get()),
       make_shared<ReadDataPort>("", RDP::DATA, Dir::OUT, Value(ce::BUS_DATA_WIDTH), stream_rdat_.get()),
       make_shared<ReadDataPort>("", RDP::LAST, Dir::OUT, stream_rdat_.get())
      });

  /* Output stream (to user core) */
  stream_out_->addPort(
      {make_shared<ArrowPort>("", ASP::VALID, Dir::OUT, user_streams, stream_out_.get()),
       make_shared<ArrowPort>("", ASP::READY, Dir::OUT, user_streams, stream_out_.get()),
       make_shared<ArrowPort>("", ASP::LAST, Dir::OUT, user_streams, stream_out_.get()),
       make_shared<ArrowPort>("", ASP::DATA, Dir::OUT, data_width, stream_out_.get()),
       make_shared<ArrowPort>("", ASP::DVALID, Dir::OUT, user_streams, stream_out_.get())
      });

  appendStream(stream_cmd_);
  appendStream(stream_unl_);
  appendStream(stream_out_);
  appendStream(stream_rreq_);
  appendStream(stream_rdat_);

  addStreamPorts();
}

/**
 * Generate a ColumnWriter
 */
ColumnWriter::ColumnWriter(Column *column, const Value &user_streams, const Value &data_width, Value &ctrl_width) :
    StreamComponent("ColumnWriter"), DerivedFrom(column) {
  /* Generics */
  entity()->addGeneric(make_shared<Generic>(ce::BUS_ADDR_WIDTH, "natural", Value(ce::BUS_ADDR_WIDTH_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_LEN_WIDTH, "natural", Value(ce::BUS_LEN_WIDTH_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_DATA_WIDTH, "natural", Value(ce::BUS_DATA_WIDTH_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_STROBE_WIDTH, "natural", Value(ce::BUS_STROBE_WIDTH_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_BURST_STEP_LEN, "natural", Value(ce::BUS_BURST_STEP_LEN_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::BUS_BURST_MAX_LEN, "natural", Value(ce::BUS_BURST_MAX_LEN_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::INDEX_WIDTH, "natural", Value(ce::INDEX_WIDTH_DEFAULT)));
  entity()->addGeneric(make_shared<Generic>(ce::CONFIG_STRING, "string", Value("\"ERROR: CONFIG STRING NOT SET\"")));

  // Create the streams
  stream_cmd_ = make_shared<CommandStream>("", column);
  stream_wreq_ = make_shared<WriteRequestStream>("bus", column);
  stream_wdat_ = make_shared<WriteDataStream>("bus", column);
  stream_in_ = make_shared<FletcherColumnStream>("", FST::WARROW, column);

  stream_unl_ = make_shared<FletcherColumnStream>("", FST::UNLOCK, column);

  // Some port widths are "?". We only make maps to these ports, and their widths depend on the configuration string.

  entity()->addPort(make_shared<GeneralPort>(ce::BUS_CLK, GP::BUS_CLK, Dir::IN));
  entity()->addPort(make_shared<GeneralPort>(ce::BUS_RST, GP::BUS_RESET, Dir::IN));
  entity()->addPort(make_shared<GeneralPort>(ce::ACC_CLK, GP::ACC_CLK, Dir::IN));
  entity()->addPort(make_shared<GeneralPort>(ce::ACC_RST, GP::ACC_RESET, Dir::IN));

  /* Command stream */
  stream_cmd_->addPort(
      {make_shared<CommandPort>("", CSP::VALID, Dir::IN, stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::READY, Dir::OUT, stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::FIRST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::LAST_INDEX, Dir::IN, Value(ce::INDEX_WIDTH), stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::CTRL, Dir::IN, ctrl_width, stream_cmd_.get()),
       make_shared<CommandPort>("", CSP::TAG, Dir::IN, Value(ce::TAG_WIDTH), stream_cmd_.get())
      });

  // TODO(johanpel): implement unlock stream
  /*
  unlock->addPort({make_shared<CommandPort>(Dir::OUT, ASP::VALID, unlock.get()),
                   make_shared<CommandPort>(Dir::IN, ASP::READY, unlock.get()),
                   make_shared<CommandPort>(Dir::OUT, Value("TAG_WIDTH"), ASP::TAG, unlock.get())
                  });
*/

  /* Write request channel */
  stream_wreq_->addPort(
      {make_shared<WriteReqPort>("", WRP::VALID, Dir::IN, stream_wreq_.get()),
       make_shared<WriteReqPort>("", WRP::READY, Dir::OUT, stream_wreq_.get()),
       make_shared<WriteReqPort>("", WRP::ADDRESS, Dir::IN, Value(ce::BUS_ADDR_WIDTH), stream_wreq_.get()),
       make_shared<WriteReqPort>("", WRP::BURSTLEN, Dir::IN, Value(ce::BUS_LEN_WIDTH), stream_wreq_.get())
      });

  /* Write data channel */
  stream_wdat_->addPort(
      {make_shared<WriteDataPort>("", WDP::VALID, Dir::OUT, stream_wdat_.get()),
       make_shared<WriteDataPort>("", WDP::READY, Dir::IN, stream_wdat_.get()),
       make_shared<WriteDataPort>("", WDP::DATA, Dir::OUT, Value(ce::BUS_DATA_WIDTH), stream_wdat_.get()),
       make_shared<WriteDataPort>("", WDP::STROBE, Dir::OUT, Value(ce::BUS_STROBE_WIDTH), stream_wdat_.get()),
       make_shared<WriteDataPort>("", WDP::LAST, Dir::OUT, stream_wdat_.get())
      });

  /* Input stream (from user core) */
  stream_in_->addPort(
      {make_shared<ArrowPort>("", ASP::VALID, Dir::OUT, user_streams, stream_in_.get()),
       make_shared<ArrowPort>("", ASP::READY, Dir::OUT, user_streams, stream_in_.get()),
       make_shared<ArrowPort>("", ASP::LAST, Dir::OUT, user_streams, stream_in_.get()),
       make_shared<ArrowPort>("", ASP::DATA, Dir::OUT, data_width, stream_in_.get()),
       make_shared<ArrowPort>("", ASP::DVALID, Dir::OUT, user_streams, stream_in_.get())
      });

  appendStream(stream_cmd_);
  appendStream(stream_unl_);
  appendStream(stream_in_);
  appendStream(stream_wreq_);
  appendStream(stream_wdat_);

  addStreamPorts();
}

std::string Column::getColumnModeString(Mode mode) {
  if (mode == Mode::READ) {
    return "Reader";
  } else {
    return "Writer";
  }
}

std::string genConfigString(const std::shared_ptr<arrow::Field>& field, int level) {
  std::string ret;
  ConfigType ct = getConfigType(field->type().get());

  if (field->nullable()) {
    ret += "null(";
    level++;
  }

  int epc = fletcher::getEPC(field);

  if (ct == ConfigType::PRIM) {
    Value w = getWidth(field->type().get());

    ret += "prim(" + w.toString();
    level++;

  } else if (ct == ConfigType::LISTPRIM) {
    ret += "listprim(";
    level++;

    Value w = Value(8);

    ret += w.toString();
  } else if (ct == ConfigType::LIST) {
    ret += "list(";
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
    auto child = field->type()->children()[c];
    ret += genConfigString(child);
    if (c != field->type()->num_children() - 1)
      ret += ",";
  }

  for (; level > 0; level--)
    ret += ")";

  return ret;
};

}  // namespace fletchgen
