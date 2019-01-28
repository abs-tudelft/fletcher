#pragma once

#include <memory>

#include "../src/types.h"
#include "../src/nodes.h"
#include "../src/edges.h"
#include "../src/graphs.h"

#include "../src/fletcher_types.h"

namespace fletchgen {

std::shared_ptr<Component> GetConcattedStreamsComponent() {
  // Data types
  auto all_type = Vector::Make<4>("all");
  auto sub_type = Vector::Make<2>("sub");
  auto all_stream = Stream::Make("all:stream", all_type);
  auto sub_stream = Stream::Make("sub:stream", sub_type);

  // Port types
  auto pA = Port::Make("A", all_stream, Port::OUT);
  auto pB = Port::Make("B", sub_stream, Port::IN);
  auto pC = Port::Make("C", sub_stream, Port::IN);

  auto pD = Port::Make("D", sub_stream, Port::OUT);
  auto pE = Port::Make("E", sub_stream, Port::OUT);
  auto pF = Port::Make("F", all_stream, Port::IN);

  // Component types
  auto top = Component::Make("top");
  auto x = Component::Make("X", {}, {pA, pD, pE}, {});
  auto y = Component::Make("Y", {}, {pB, pC, pF}, {});
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