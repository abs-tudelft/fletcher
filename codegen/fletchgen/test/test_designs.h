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

#include "../src/types.h"
#include "../src/nodes.h"
#include "../src/edges.h"
#include "../src/graphs.h"

#include "../src/fletcher_types.h"

namespace fletchgen {

std::shared_ptr<Component> GetConcatStreamsComponent() {
  auto par_width = Parameter::Make("WIDTH", integer());

  // Data type
  auto data_type = Vector::Make("data", par_width);

  // Port type
  auto pA = Port::Make("A", data_type, Port::OUT);
  auto pB = Port::Make("B", data_type, Port::IN);
  auto pC = Port::Make("C", data_type, Port::IN);

  auto pD = Port::Make("D", data_type, Port::OUT);
  auto pE = Port::Make("E", data_type, Port::OUT);
  auto pF = Port::Make("F", data_type, Port::IN);

  // Component types
  auto top = Component::Make("top", {par_width}, {}, {});
  auto x = Component::Make("X", {par_width}, {pA, pD, pE}, {});
  auto y = Component::Make("Y", {par_width}, {pB, pC, pF}, {});

  auto x_inst = Instance::Make(x);
  auto y_inst = Instance::Make(y);

  top->AddChild(x_inst)
      .AddChild(y_inst);

  y_inst->Get(Node::PORT, "B") <<= x_inst->Get(Node::PORT, "A");
  y_inst->Get(Node::PORT, "C") <<= x_inst->Get(Node::PORT, "A");
  y_inst->Get(Node::PORT, "F") <<= x_inst->Get(Node::PORT, "D");
  y_inst->Get(Node::PORT, "F") <<= x_inst->Get(Node::PORT, "E");

  return top;
}

std::shared_ptr<Component> GetAllPortTypesComponent() {
  auto r_type = Record::Make("rec", {
      RecordField::Make("a", int8()),
      RecordField::Make("b", float32())
  });
  auto s_type = Stream::Make("stream", uint32());

  auto clk_port = Port::Make(acc_clk());
  auto rst_port = Port::Make(acc_reset());
  auto b_port = Port::Make("some_bool", boolean(), Port::OUT);
  auto v_port = Port::Make("some_vector", uint16());
  auto r_port = Port::Make("some_record", r_type, Port::OUT);
  auto s_port = Port::Make("some_port", s_type);

  auto l = litint<16>();
  auto par = Parameter::Make("depth", integer(), l);

  auto a_type = Component::Make("a", {par}, {clk_port, rst_port, b_port, v_port, r_port, s_port}, {});

  return a_type;
}

}