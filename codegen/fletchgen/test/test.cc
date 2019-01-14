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

#include <vector>
#include <memory>

#include <arrow/api.h>
#include <arrow/builder.h>
#include <arrow/record_batch.h>

#include "gtest/gtest.h"

#include "../src/stream/vhdl.h"
#include "../src/stream/dot.h"

namespace fletchgen {
namespace stream {

TEST(Declarators, Components) {
  auto clk_domain = ClockDomain::Make("acc");

  auto clk_type = Clock::Make("clk", clk_domain);
  auto rst_type = Reset::Make("reset", clk_domain);
  auto b_type = Bit::Make("bit");
  auto v_type = Vector::Make("vector8", 0, 7);
  auto i_type = Signed::Make("int16", 0, 15);
  auto u_type = Unsigned::Make("uint64", 0, 63);
  auto r_type = Record::Make("record", {
      RecordField::Make("a", i_type),
      RecordField::Make("b", u_type)
  });
  auto n_type = Natural::Make("natural");
  auto s_type = Stream::Make("stream", i_type);

  auto clk_port = Port::Make("clk", clk_type, Port::IN);
  auto rst_port = Port::Make("rst", rst_type, Port::IN);
  auto b_port = Port::Make("bit", b_type, Port::IN);
  auto v_port = Port::Make("vec", v_type, Port::IN);
  auto i_port = Port::Make("int", i_type, Port::IN);
  auto u_port = Port::Make("uint", u_type, Port::IN);
  auto r_port = Port::Make("rec", r_type, Port::IN);
  auto n_port = Port::Make("nat", n_type, Port::IN);
  auto s_port = Port::Make("str", s_type, Port::IN);

  auto par = Parameter::Make("depth", n_type);
  auto lit = Literal::Make("default_depth", n_type, "16");

  auto a_type = ComponentType::Make("comp_a", {par}, {
      clk_port,
      rst_port,
      b_port,
      v_port,
      i_port,
      u_port,
      r_port,
      n_port,
      s_port
  });

  std::cout << vhdl::Declarator::Generate(a_type) << std::endl;
}

TEST(Instantiators, StreamConcat) {
  // Clock domain
  auto clk_domain = ClockDomain::Make("clk");

  // Data types
  auto all_type = Vector::Make("all", 0, 3);
  auto sub_type = Vector::Make("sub", 0, 1);
  auto source_type = Stream::Make("source", all_type);
  auto sink_type = Stream::Make("sink", sub_type);

  // Port types
  auto source_port = Port::Make("source", source_type, Port::OUT);
  auto sink0_port = Port::Make("sink0", sink_type, Port::IN);
  auto sink1_port = Port::Make("sink1", sink_type, Port::IN);

  // Component types

  // Top
  auto top_comp_type = ComponentType::Make("top", {}, {});

  // Source
  auto source_comp_type = ComponentType::Make("comp_source", {}, {
      source_port
  });

  // Sink
  auto sink_comp_type = ComponentType::Make("comp_sink", {}, {
      sink0_port,
      sink1_port
  });

  // Component instantiations
  auto top = Component::Instantiate("top", top_comp_type);
  auto source = Component::Instantiate("source_inst", source_comp_type);
  auto sink = Component::Instantiate("sink_inst", sink_comp_type);

  // Signal node types instantiation
  auto stream_type = Signal::Make("stream", sink_type);

  // Signal nodes
  auto stream0 = Signal::ToNode("stream0", stream_type);
  auto stream1 = Signal::ToNode("stream1", stream_type);

  // Add signal nodes to top level component
  top->AddNode(stream0)
      .AddNode(stream1);

  // Connect stream source
  stream0 <<= source->GetNode(NodeType::PORT, "source");
  stream1 <<= source->GetNode(NodeType::PORT, "source");

  // Connect stream sink
  sink->GetNode(NodeType::PORT, "sink0") <<= stream0;
  sink->GetNode(NodeType::PORT, "sink1") <<= stream1;

  // Generate instantiations
  std::cout << vhdl::Instantiator::Generate(source);
  std::cout << vhdl::Instantiator::Generate(sink);

  std::cout << "digraph {\n";
  std::cout << dot::Grapher::Edges(source);
  std::cout << dot::Grapher::Edges(sink);
  std::cout << "  subgraph cluster_" << source->name() << "{\n";
  std::cout << "    label=\"" << source->name() << "\";\n";
  std::cout << dot::Grapher::Nodes(source);
  std::cout << "  }\n";
  std::cout << "  subgraph cluster_" << sink->name() << "{\n";
  std::cout << "    label=\"" << sink->name() << "\";\n";
  std::cout << dot::Grapher::Nodes(sink);
  std::cout << "  }\n";
  std::cout << "}\n";
}

}
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}