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

#include <memory>

#include "cerata/edges.h"
#include "cerata/types.h"
#include "cerata/nodes.h"
#include "cerata/graphs.h"

#include "fletchgen/basic_types.h"
#include "fletchgen/bus.h"
#include "fletchgen/column.h"
#include "fletchgen/mantle.h"

namespace fletchgen {

std::shared_ptr<Component> GetColumnReadersAndArbiter() {
  auto top = Component::Make("top");

  auto cr0 = Instance::Make("cr0", ColumnReader());
  auto cr1 = Instance::Make("cr1", ColumnReader());
  auto bra = Instance::Make("bra", BusReadArbiter());

  std::shared_ptr<Node> bra_rreq = bra->ap("bsv_rreq");
  std::shared_ptr<Node> cr0_rreq = cr0->Get(Node::PORT, "bus_rreq");
  std::shared_ptr<Node> cr1_rreq = cr1->Get(Node::PORT, "bus_rreq");

  std::shared_ptr<Node> bra_rdat = bra->ap("bsv_rdat");
  std::shared_ptr<Node> cr0_rdat = cr0->Get(Node::PORT, "bus_rdat");
  std::shared_ptr<Node> cr1_rdat = cr1->Get(Node::PORT, "bus_rdat");

  bra_rreq <<= cr0_rreq;
  bra_rreq <<= cr1_rreq;

  bra_rdat <<= cr0_rdat;
  bra_rdat <<= cr1_rdat;

  top->AddChild(bra)
      .AddChild(cr0)
      .AddChild(cr1);

  return top;
}

}
