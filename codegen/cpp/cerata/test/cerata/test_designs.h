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

#include <cerata/api.h>

#include <vector>
#include <memory>
#include <utility>
#include <string>

namespace cerata {

std::shared_ptr<Component> GetTypeExpansionComponent() {
  auto width = Parameter::Make("width", integer(), intl(8));
  auto vec_type = Vector::Make("data", width);
  auto rec_type = Record::Make("rec_type", {
      RecField::Make("cerata", vec_type),
      RecField::Make("is", vec_type),
      RecField::Make("awesome", vec_type)
  });
  auto stream_type = Stream::Make("stream_type", rec_type);
  auto data_in = Port::Make("data", stream_type, Port::Dir::IN);
  auto data_out = Port::Make("data", stream_type, Port::Dir::OUT);
  auto foo = Component::Make("foo", {width, data_in});
  auto bar = Component::Make("bar", {width, data_out});
  auto top = Component::Make("top");
  auto foo_inst = top->AddInstanceOf(foo.get(), "foo");
  auto bar_inst = top->AddInstanceOf(bar.get(), "bar");
  Connect(foo_inst->port("data"), bar_inst->port("data"));
  return top;
}

std::shared_ptr<Component> GetArrayToArrayInternalComponent(bool invert = false) {
  auto data = Vector::Make<8>();

  std::string a = invert ? "src" : "dst";
  std::string x = invert ? "dst0" : "src0";
  std::string y = invert ? "dst1" : "src1";

  auto top_comp = Component::Make("top_comp");

  auto a_size = Parameter::Make("size", integer(), intl(0));
  auto a_array = PortArray::Make("array", data, a_size, invert ? Term::IN : Term::OUT);
  auto a_comp = Component::Make(a, {a_size, a_array});
  auto a_inst = Instance::Make(a_comp.get());

  auto x_size = Parameter::Make("size", integer(), intl(0));
  auto x_array = PortArray::Make("array", data, x_size, invert ? Term::OUT : Term::IN);
  auto x_comp = Component::Make(x, {x_size, x_array});
  auto x_inst = Instance::Make(x_comp.get());

  auto y_size = Parameter::Make("size", integer(), intl(0));
  auto y_array = PortArray::Make("array", data, y_size, invert ? Term::OUT : Term::IN);
  auto y_comp = Component::Make(y, {y_size, y_array});
  auto y_inst = Instance::Make(y_comp.get());

  a_inst->porta("array")->Append();
  a_inst->porta("array")->Append();
  a_inst->porta("array")->Append();
  a_inst->porta("array")->Append();

  x_inst->porta("array")->Append();
  x_inst->porta("array")->Append();
  y_inst->porta("array")->Append();
  y_inst->porta("array")->Append();

  if (!invert) {
    Connect(x_inst->porta("array")->node(0), a_inst->porta("array")->node(1));
    Connect(x_inst->porta("array")->node(1), a_inst->porta("array")->node(0));
    Connect(y_inst->porta("array")->node(0), a_inst->porta("array")->node(3));
    Connect(y_inst->porta("array")->node(1), a_inst->porta("array")->node(2));
  } else {
    Connect(a_inst->porta("array")->node(1), x_inst->porta("array")->node(0));
    Connect(a_inst->porta("array")->node(0), x_inst->porta("array")->node(1));
    Connect(a_inst->porta("array")->node(3), y_inst->porta("array")->node(0));
    Connect(a_inst->porta("array")->node(2), y_inst->porta("array")->node(1));
  }

  top_comp->AddChild(std::move(a_inst));
  top_comp->AddChild(std::move(x_inst));
  top_comp->AddChild(std::move(y_inst));
  return top_comp;
}

std::shared_ptr<Component> GetArrayToArrayComponent(bool invert = false) {
  auto data = Vector::Make<8>();

  auto top_size = Parameter::Make("top_size", integer(), intl(0));
  auto top_array = PortArray::Make("top_array", data, top_size, invert ? Term::OUT : Term::IN);
  auto top_comp = Component::Make("top_comp", {top_size, top_array});

  auto child_size = Parameter::Make("child_size", integer(), intl(0));
  auto child_array = PortArray::Make("child_array", data, child_size, invert ? Term::OUT : Term::IN);
  auto child_comp = Component::Make("child_comp", {child_size, child_array});
  auto child_inst = Instance::Make(child_comp.get());

  if (invert) {
    child_inst->porta("child_array")->Append();
    top_array->Append();
    top_array->Append();
    Connect(top_array->node(0), child_inst->porta("child_array")->node(0));
    Connect(top_array->node(1), child_inst->porta("child_array")->node(0));
  } else {
    child_inst->porta("child_array")->Append();
    child_inst->porta("child_array")->Append();
    top_array->Append();
    Connect(child_inst->porta("child_array")->node(0), top_array->node(0));
    Connect(child_inst->porta("child_array")->node(1), top_array->node(0));
  }
  top_comp->AddChild(std::move(child_inst));
  return top_comp;
}

std::shared_ptr<Component> GetArrayComponent() {
  auto size = Parameter::Make("size", integer(), intl(0));
  auto data = Vector::Make<8>();
  auto pA = PortArray::Make("A", data, size, Term::OUT);
  auto pB = Port::Make("B", data, Term::IN);
  auto pC = Port::Make("C", data, Term::IN);

  auto top = Component::Make("top");
  auto x_comp = Component::Make("X", {size, pA});
  auto y_comp = Component::Make("Y", {pB, pC});

  auto x = Instance::Make(x_comp.get());
  auto y = Instance::Make(y_comp.get());

  Connect(y->port("B"), x->porta("A")->Append());
  Connect(y->port("C"), x->porta("A")->Append());

  top->AddChild(std::move(x))
      .AddChild(std::move(y));

  return top;
}

std::shared_ptr<Component> GetTypeConvComponent() {
  auto t_wide = Vector::Make<4>();
  auto t_narrow = Vector::Make<2>();
  // Flat indices:
  auto tA = Record::Make("rec_A", {       // 0
      RecField::Make("q", t_wide),     // 1
      RecField::Make("r", t_narrow),   // 2
      RecField::Make("s", t_narrow),   // 3
      RecField::Make("t", t_wide),     // 4
  });

  auto tB = Record::Make("rec_B", {       // 0
      RecField::Make("u", t_wide),     // 1
      RecField::Make("v", t_narrow),   // 2
      RecField::Make("w", t_narrow),   // 3
      RecField::Make("x", t_wide),     // 4
  });

  // Create a type mapping from tA to tE
  auto mapper = std::make_shared<TypeMapper>(tA.get(), tB.get());
  mapper->Add(0, 0);
  mapper->Add(1, 2).Add(1, 3);
  mapper->Add(3, 1);
  mapper->Add(2, 1);
  mapper->Add(4, 4);
  tA->AddMapper(mapper);

  // Ports
  auto pA = Port::Make("A", tA, Port::OUT);
  auto pB = Port::Make("B", tB, Port::IN);

  // Components and instantiations
  auto top = Component::Make("top");
  auto x_comp = Component::Make("X", {pA});
  auto y_comp = Component::Make("Y", {pB});
  auto x = Instance::Make(x_comp.get());
  auto y = Instance::Make(y_comp.get());
  auto xr = x.get();
  auto yr = y.get();
  top->AddChild(std::move(x))
      .AddChild(std::move(y));

  // Connect ports
  Connect(yr->port("B"), xr->port("A"));

  return top;
}

std::shared_ptr<Component> GetArrayTypeConvComponent() {
  auto t_wide = Vector::Make<4>();
  auto t_narrow = Vector::Make<2>();
  // Flat indices:
  auto tA = Record::Make("Type _A", {    // 0
      RecField::Make("q", t_wide),     // 1
  });

  auto tB = Record::Make("Type B", {    // 0
      RecField::Make("r", t_narrow),   // 1
      RecField::Make("s", t_narrow),   // 2
  });

  // Create a type mapping from tA to tE
  auto mapper = std::make_shared<TypeMapper>(tA.get(), tB.get());
  mapper->Add(1, 1);
  mapper->Add(1, 2);
  tA->AddMapper(mapper);

  // Ports
  auto parSize = Parameter::Make("ARRAY_SIZE", integer(), intl(0));
  auto pA = PortArray::Make("A", tA, parSize, Port::OUT);
  auto pB = Port::Make("B", tB, Port::OUT);
  auto pC = Port::Make("C", tB, Port::OUT);

  // Components and instantiations
  auto top = Component::Make("top", {pB, pC});
  auto x_comp = Component::Make("X", {pA});
  auto x = Instance::Make(x_comp.get());
  auto xr = x.get();
  top->AddChild(std::move(x));

  // Drive B and C from A
  pB <<= xr->porta("A")->Append();
  pC <<= xr->porta("A")->Append();

  return top;
}

std::shared_ptr<Component> GetStreamConcatComponent() {
  // Flat indices:
  auto tA = Stream::Make("split",                                 // 0
                         Record::Make("a", {                      // 1
                             RecField::Make("other",
                                            bit()),               // 2
                             RecField::Make("child",
                                            Stream::Make("se",    // 3
                                                         bit()))  // 4
                         }));

  auto tB = Stream::Make("concat",  // 0
                         bit(),     // 1
                         "data");

  auto tC = Stream::Make("concat",  // 0
                         bit(),     // 1
                         "data");

  // Create a type mapping from tA to tB
  auto mapperB = std::make_shared<TypeMapper>(tA.get(), tB.get());
  mapperB->Add(0, 0);
  mapperB->Add(2, 1);
  mapperB->Add(3, 0);
  mapperB->Add(4, 1);
  tA->AddMapper(mapperB);

  // Create a type mapping from tA to tC
  auto mapperC = std::make_shared<TypeMapper>(tA.get(), tC.get());
  mapperC->Add(0, 0);
  mapperC->Add(2, 1);
  mapperC->Add(3, 0);
  mapperC->Add(4, 1);
  tA->AddMapper(mapperC);

  // Ports
  auto pA0 = Port::Make("A0", tA, Port::OUT);
  auto pA1 = Port::Make("A1", tA, Port::OUT);
  auto pB = Port::Make("B", tB, Port::OUT);
  auto pC = Port::Make("C", tC, Port::OUT);

  // Components and instantiations
  auto x_comp = Component::Make("X", {pA0, pA1});
  auto y_comp = Component::Make("Y", {pB, pC});
  y_comp->meta()[vhdl::metakeys::PRIMITIVE] = "true";
  y_comp->meta()[vhdl::metakeys::LIBRARY] = "test";
  y_comp->meta()[vhdl::metakeys::PACKAGE] = "test";
  auto y = Instance::Make(y_comp.get());
  auto yr = y.get();
  x_comp->AddChild(std::move(y));

  // Connect ports
  Connect(x_comp->port("A0"), yr->port("B"));
  Connect(x_comp->port("A1"), yr->port("C"));

  return x_comp;
}

std::shared_ptr<Component> GetAllPortTypesComponent() {
  auto r_type = Record::Make("rec", {
      RecField::Make("a", Vector::Make<8>()),
      RecField::Make("b", Vector::Make<32>())
  });
  auto s_type = Stream::Make("stream", Vector::Make<16>());

  auto clk_domain = ClockDomain::Make("domain0");
  auto clk_port = Port::Make("clk", bit(), Port::Dir::IN, clk_domain);
  auto rst_port = Port::Make("reset", bit(), Port::Dir::IN, clk_domain);
  auto b_port = Port::Make("some_bool", boolean(), Port::OUT);
  auto v_port = Port::Make("some_vector", Vector::Make<64>());
  auto r_port = Port::Make("some_record", r_type, Port::OUT);
  auto s_port = Port::Make("some_port", s_type);

  auto par = Parameter::Make("depth", integer(), intl(16));

  auto a_type = Component::Make("a", {par, clk_port, rst_port, b_port, v_port, r_port, s_port});

  return a_type;
}

std::shared_ptr<Component> GetExampleDesign() {
  auto vec_width = Parameter::Make("vec_width", integer(), intl(32));
  // Construct a deeply nested type to showcase Cerata's capabilities.
  auto my_type = Record::Make("my_record_type", {RecField::Make("bit", bit()),
                                                 RecField::Make("vec", Vector::Make("param_vec", vec_width)),
                                                 RecField::Make("stream",
                                                                Stream::Make("d", Record::Make("other_rec_type", {
                                                                    RecField::Make("substream",
                                                                                   Stream::Make(Vector::Make<32>())),
                                                                    RecField::Make("int", integer())})))});

  // Construct two components with a port made from these types
  auto my_array_size = Parameter::Make("array_size", integer());
  auto my_comp = Component::Make("my_comp", {vec_width,
                                             PortArray::Make("my_array", my_type, my_array_size, Port::OUT)});

  auto my_other_comp = Component::Make("my_other_comp", {vec_width,
                                                         Port::Make("my_port", my_type)});

  // Create a top level and add instances of each component
  auto my_top = Component::Make("my_top_level");
  auto my_inst = my_top->AddInstanceOf(my_comp.get());

  // Create a bunch of instances and connect to other component
  std::vector<Instance *> my_other_instances;
  for (int i = 0; i < 10; i++) {
    my_other_instances.push_back(my_top->AddInstanceOf(my_other_comp.get(), "my_inst_" + std::to_string(i)));
    Connect(my_other_instances[i]->port("my_port"), my_inst->porta("my_array")->Append());
  }

  return my_top;
}

}  // namespace cerata
