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

#include "arbiter.h"

using vhdl::Generic;

namespace fletchgen {

using vhdl::t;

ReadArbiter::ReadArbiter(int num_slave_ports) : StreamComponent("BusReadArbiterVec") {

  // Create the streams for the top level
  slv_rreq_ = std::make_shared<ReadRequestStream>("bsv");
  slv_rdat_ = std::make_shared<ReadDataStream>("bsv");
  mst_rreq_ = std::make_shared<ReadRequestStream>("mst");
  mst_rdat_ = std::make_shared<ReadDataStream>("mst");

  appendStream(slv_rreq_);
  appendStream(slv_rdat_);
  appendStream(mst_rreq_);
  appendStream(mst_rdat_);

  auto slv_rreq = slv_rreq_.get();
  auto slv_rdat = slv_rdat_.get();
  auto mst_rreq = mst_rreq_.get();
  auto mst_rdat = mst_rdat_.get();

  entity()->addPort(std::make_shared<GeneralPort>(ce::BUS_CLK, GP::BUS_CLK, Dir::IN));
  entity()->addPort(std::make_shared<GeneralPort>(ce::BUS_RST, GP::BUS_RESET, Dir::IN));

  Value hs_width = Value(num_slave_ports);
  Value addr_width = Value(ce::BUS_ADDR_WIDTH) * num_slave_ports;
  Value len_width = Value(ce::BUS_LEN_WIDTH) * num_slave_ports;
  Value data_width = Value(ce::BUS_DATA_WIDTH) * num_slave_ports;

  slv_rreq_->addPort({std::make_shared<ReadReqPort>("", RRP::VALID, Dir::IN, hs_width, slv_rreq),
                      std::make_shared<ReadReqPort>("", RRP::READY, Dir::OUT, hs_width, slv_rreq),
                      std::make_shared<ReadReqPort>("", RRP::ADDRESS, Dir::IN, addr_width, slv_rreq),
                      std::make_shared<ReadReqPort>("", RRP::BURSTLEN, Dir::IN, len_width, slv_rreq)
                     });

  slv_rdat_->addPort({std::make_shared<ReadDataPort>("", RDP::VALID, Dir::OUT, hs_width, slv_rdat),
                      std::make_shared<ReadDataPort>("", RDP::READY, Dir::IN, hs_width, slv_rdat),
                      std::make_shared<ReadDataPort>("", RDP::DATA, Dir::OUT, data_width, slv_rdat),
                      std::make_shared<ReadDataPort>("", RDP::LAST, Dir::OUT, hs_width, slv_rdat)
                     });

  mst_rreq_->addPort({std::make_shared<ReadReqPort>("", RRP::VALID, Dir::OUT, mst_rreq),
                      std::make_shared<ReadReqPort>("", RRP::READY, Dir::IN, mst_rreq),
                      std::make_shared<ReadReqPort>("", RRP::ADDRESS, Dir::OUT, Value(ce::BUS_ADDR_WIDTH), mst_rreq),
                      std::make_shared<ReadReqPort>("", RRP::BURSTLEN, Dir::OUT, Value(ce::BUS_LEN_WIDTH), mst_rreq)
                     });

  mst_rdat_->addPort({std::make_shared<ReadDataPort>("", RDP::VALID, Dir::IN, mst_rdat),
                      std::make_shared<ReadDataPort>("", RDP::READY, Dir::OUT, mst_rdat),
                      std::make_shared<ReadDataPort>("", RDP::DATA, Dir::IN, Value(ce::BUS_DATA_WIDTH), mst_rdat),
                      std::make_shared<ReadDataPort>("", RDP::LAST, Dir::IN, mst_rdat)
                     });

  entity()->addGeneric(std::make_shared<Generic>(ce::BUS_ADDR_WIDTH, "natural", Value(32)));
  entity()->addGeneric(std::make_shared<Generic>(ce::BUS_LEN_WIDTH, "natural", Value(8)));
  entity()->addGeneric(std::make_shared<Generic>(ce::BUS_DATA_WIDTH, "natural", Value(32)));
  entity()->addGeneric(std::make_shared<Generic>("NUM_SLAVE_PORTS", "natural", Value(2)));
  entity()->addGeneric(std::make_shared<Generic>("ARB_METHOD", "string", Value("ROUND-ROBIN")));
  entity()->addGeneric(std::make_shared<Generic>("MAX_OUTSTANDING", "natural", Value(2)));
  entity()->addGeneric(std::make_shared<Generic>("RAM_CONFIG", "string", Value("")));
  entity()->addGeneric(std::make_shared<Generic>("SLV_REQ_SLICES", "boolean", Value("false")));
  entity()->addGeneric(std::make_shared<Generic>("MST_REQ_SLICE", "boolean", Value("true")));
  entity()->addGeneric(std::make_shared<Generic>("MST_DAT_SLICE", "boolean", Value("false")));
  entity()->addGeneric(std::make_shared<Generic>("SLV_DAT_SLICES", "boolean", Value("true")));

  addStreamPorts();
}

}//namespace fletchgen
