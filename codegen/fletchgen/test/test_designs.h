#pragma once

#include <memory>

#include "../src/types.h"
#include "../src/nodes.h"
#include "../src/components.h"

#include "../src/fletcher_types.h"

namespace fletchgen {

std::shared_ptr<Component> GetConcattedStreamsComponent() {
  // Data types
  auto all_type = Vector::Make<4>("all");
  auto sub_type = Vector::Make<2>("sub");
  auto all_stream = Stream::Make(all_type);
  auto sub_stream = Stream::Make(sub_type);

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

  top->Add(x)
      .Add(y);

  // Signals
  auto sB = Signal::Make("int_B", sub_stream);
  auto sC = Signal::Make("int_C", sub_stream);
  auto sF = Signal::Make("int_F", all_stream);

  top->Add(sB)
      .Add(sC)
      .Add(sF);

  // Connect
  sB <<= x->Get(Node::PORT, "A");
  sC <<= x->Get(Node::PORT, "A");
  sF <<= x->Get(Node::PORT, "D");
  sF <<= x->Get(Node::PORT, "E");

  y->Get(Node::PORT, "B") <<= sB;
  y->Get(Node::PORT, "C") <<= sC;
  y->Get(Node::PORT, "F") <<= sF;

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

  auto l = lit<16>();
  auto par = Parameter::Make("depth", natural(), l);

  auto a_type = Component::Make("a", {par}, {clk_port, rst_port, b_port, v_port, r_port, s_port}, {});

  return a_type;
}

}