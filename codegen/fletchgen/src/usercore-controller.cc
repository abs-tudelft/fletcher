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
#include <utility>

#include "fletcher-ports.h"

#include "usercore-controller.h"
#include "common.h"

using vhdl::Dir;

namespace fletchgen {

UserCoreController::UserCoreController() : Component("UserCoreController") {
  // Accelerator clock
  auto aclk = std::make_shared<GeneralPort>(ce::ACC_CLK, GP::ACC_CLK, Dir::IN);
  auto areset = std::make_shared<GeneralPort>(ce::ACC_RST, GP::ACC_RESET, Dir::IN);
  // Bus clock
  auto bclk = std::make_shared<GeneralPort>(ce::BUS_CLK, GP::BUS_CLK, Dir::IN);
  auto breset = std::make_shared<GeneralPort>(ce::BUS_RST, GP::BUS_RESET, Dir::IN);

  entity()->addPort(aclk, 0);
  entity()->addPort(areset, 0);
  entity()->addPort(bclk, 0);
  entity()->addPort(breset, 0);

  status_ = std::make_shared<GeneralPort>("status", GP::SIG, Dir::OUT, Value(ce::REG_WIDTH));
  ctrl_ = std::make_shared<GeneralPort>("control", GP::REG_CONTROL, Dir::IN, Value(ce::REG_WIDTH));
  start_ = std::make_shared<GeneralPort>("start", GP::REG_STATUS, Dir::OUT);
  stop_ = std::make_shared<GeneralPort>("stop", GP::SIG, Dir::OUT);
  reset_ = std::make_shared<GeneralPort>("reset", GP::SIG, Dir::OUT);
  idle_ = std::make_shared<GeneralPort>("idle", GP::SIG, Dir::IN);
  busy_ = std::make_shared<GeneralPort>("busy", GP::SIG, Dir::IN);
  done_ = std::make_shared<GeneralPort>("done", GP::SIG, Dir::IN);

  entity()->addPort(status_, 1);
  entity()->addPort(ctrl_, 1);

  entity()->addPort(start_, 2);
  entity()->addPort(stop_, 2);
  entity()->addPort(reset_, 2);

  entity()->addPort(idle_, 3);
  entity()->addPort(busy_, 3);
  entity()->addPort(done_, 3);

  entity()
      ->addGeneric(std::make_shared<vhdl::Generic>(ce::REG_WIDTH, "natural", Value(ce::REG_WIDTH_DEFAULT)));
}

}
