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

#include <gtest/gtest.h>

#include "cerata/vhdl/vhdl.h"
#include "cerata/dot/dot.h"
#include "cerata/edges.h"

#include "fletchgen/bus.h"

namespace fletchgen {

using cerata::intl;
using cerata::Instance;
using cerata::Port;

TEST(Bus, BusReadArbiter) {
  auto top = BusReadArbiter();

  auto design = cerata::vhdl::Design(top);
  std::cout << design.Generate().ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Bus, Artery) {
  // Create a bunch of read data ports
  auto a = Port::Make("a", bus_read_data(intl<8>()));
  auto b = Port::Make("b", bus_read_data(intl<8>()));
  auto c = Port::Make("c", bus_read_data(intl<8>()));
  auto d = Port::Make("d", bus_read_data(intl<32>()));
  auto e = Port::Make("e", bus_read_data(intl<32>()));
  auto f = Port::Make("f", bus_read_data(intl<128>()));

  // Create a component with the ports
  auto comp = Component::Make("comp", {}, {a, b, c, d, e, f}, {});

  // Create an artery able to handle these ports
  auto artery = Artery::Make(intl<64>(), intl<512>(), {intl<8>(), intl<32>(), intl<128>()});

  // Instaniate component and artery
  auto comp_inst = Instance::Make(comp);
  auto art_inst = ArteryInstance::Make(artery);

  // Get the read data ports with the specified widths
  auto rd8 = art_inst->read_data<8>();
  auto rd32 = art_inst->read_data<32>();
  auto rd128 = art_inst->read_data<128>();

  // Append the component ports to it
  comp_inst->port("a") <<= rd8;
  comp_inst->port("b") <<= rd8;
  comp_inst->port("c") <<= rd8;
  comp_inst->port("d") <<= rd32;
  comp_inst->port("e") <<= rd32;
  comp_inst->port("f") <<= rd128;

  // Create a component
  auto top = Component::Make("top", {}, {}, {});
  top->AddChild(std::move(comp_inst));
  top->AddChild(std::move(art_inst));

  auto artery_design = cerata::vhdl::Design(artery);
  auto top_design = cerata::vhdl::Design(top);

  std::cout << artery_design.Generate().ToString();
  //std::cout << top_design.Generate().ToString();

  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(artery, "artery.dot");
  std::cout << dot.GenFile(top, "graph.dot");
}

}
