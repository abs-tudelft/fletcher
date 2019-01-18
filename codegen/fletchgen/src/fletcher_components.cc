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

#include "./fletcher_types.h"
#include "./fletcher_components.h"

namespace fletchgen {

std::shared_ptr<Component> BusReadArbiterVec() {

  auto ret = Component::Make("BusReadArbiterVec",
                             {Parameter::Make("BUS_ADDR_WIDTH", natural(), lit<32>()),
                              Parameter::Make("BUS_LEN_WIDTH", natural(), lit<32>()),
                              Parameter::Make("BUS_DATA_WIDTH", natural(), lit<32>()),
                              Parameter::Make("NUM_SLAVE_PORTS", natural(), lit<32>()),
                              Parameter::Make("ARB_METHOD", string(), Literal::Make("ROUND-ROBIN")),
                              Parameter::Make("MAX_OUTSTANDING", natural(), lit<2>()),
                              Parameter::Make("RAM_CONFIG", string(), Literal::Make("")),
                              Parameter::Make("SLV_REQ_SLICES", boolean(), bool_true()),
                              Parameter::Make("MST_REQ_SLICE", boolean(), bool_true()),
                              Parameter::Make("MST_DAT_SLICE", boolean(), bool_true()),
                              Parameter::Make("SLV_DAT_SLICES", boolean(), bool_true())},
                             {Port::Make(bus_clk()),
                              Port::Make(bus_reset()),
                              Port::Make("mst_rreq", bus_read_request(), Port::Dir::OUT),
                              Port::Make("mst_rdat", bus_read_data(), Port::Dir::IN),
                              Port::Make("bsv_rreq", bus_write_request(), Port::Dir::IN),
                              Port::Make("bsv_rdat", bus_read_data(), Port::Dir::OUT)
                             },
                             {}
  );

  return ret;
};

}