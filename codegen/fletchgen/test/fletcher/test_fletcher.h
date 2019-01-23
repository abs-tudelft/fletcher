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

#include <arrow/api.h>
#include <gtest/gtest.h>
#include <deque>
#include <memory>
#include <vector>

#include "test_schemas.h"

#include "../../src/vhdl/vhdl.h"
#include "../../src/dot/dot.h"

#include "../../src/fletcher_types.h"
#include "../../src/fletcher_components.h"

#include "./test_fletcher_designs.h"

namespace fletchgen {

TEST(Fletcher, FletcherBusReadArbiter) {
  auto brav = BusReadArbiter();

  auto source = vhdl::Declarator::Generate(brav);
  std::cout << source.str();
}

TEST(Fletcher, CRBRA) {
  // Get component
  auto top = GetColumnReadersAndArbiter();
  // Generate graph
  dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Fletcher, PrimRead) {
  auto schema = fletcher::test::GetPrimReadSchema();
  std::deque<std::shared_ptr<arrow::Schema>> schemas = {schema};
  auto uc = UserCore::Make(schemas);

  dot::Grapher dot;
  std::cout << dot.GenFile(uc, "graph.dot");
}

TEST(Fletcher, StringRead) {
  auto schema = fletcher::test::GetStringReadSchema();
  std::deque<std::shared_ptr<arrow::Schema>> schemas = {schema};
  auto uc = UserCore::Make(schemas);

  auto code = vhdl::Declarator::Generate(std::dynamic_pointer_cast<Graph>(uc));
  std::cout << code.str();

  dot::Grapher dot;
  std::cout << dot.GenFile(uc, "graph.dot");
}

TEST(Fletcher, ListPrim) {
  auto schema = fletcher::test::GetListUint8Schema();
  std::deque<std::shared_ptr<arrow::Schema>> schemas = {schema};
  auto uc = UserCore::Make(schemas);

  auto code = vhdl::Declarator::Generate(std::dynamic_pointer_cast<Graph>(uc));
  std::cout << code.str();

  dot::Grapher dot;
  std::cout << dot.GenFile(uc, "graph.dot");
}

TEST(Fletcher, BigSchema) {
  auto schema = fletcher::test::GetBigSchema();
  std::deque<std::shared_ptr<arrow::Schema>> schemas = {schema};
  auto uc = UserCore::Make(schemas);

  auto code = vhdl::Declarator::Generate(std::dynamic_pointer_cast<Graph>(uc));
  std::cout << code.str();

  dot::Grapher dot;
  std::cout << dot.GenFile(uc, "graph.dot");
}

TEST(Fletcher, BigSchema_UC_BRA_CR) {
  auto top = Component::Make("top");

  auto schema = fletcher::test::GetBigSchema();
  std::deque<std::shared_ptr<arrow::Schema>> schemas = {schema};

  auto bra_inst = Instance::Make("BusReadArbiter_inst", BusReadArbiter());
  top->Add(bra_inst);

  auto uc = UserCore::Make(schemas);
  auto uc_inst = Instance::Make("UserCore", uc);
  top->Add(uc_inst);

  std::vector<std::shared_ptr<Instance>> crs;
  for (const auto &f : schema->fields()) {
    auto cr_inst = Instance::Make(f->name() + "_cr_inst", ColumnReader());
    crs.push_back(cr_inst);
    top->Add(cr_inst);
  }

  // Connect Bus
  auto bra_slv_rreq = bra_inst->Get(Node::PORT, "bsv_rreq");
  auto bra_slv_rdat = bra_inst->Get(Node::PORT, "bsv_rdat");

  for (const auto &cr : crs) {
    auto cr_rreq = cr->Get(Node::PORT, "bus_rreq");
    auto edge = bra_slv_rreq <<= cr_rreq;
  }

  for (const auto &cr : crs) {
    auto cr_rdat = cr->Get(Node::PORT, "bus_rdat");
    auto edge = cr_rdat <<= bra_slv_rdat;
  }

  // Connect Fields
  auto uc_ports = uc_inst->GetAll<Port>();
  for (int i = 0; i < uc_ports.size(); i++) {
    auto data_stream = crs[i]->Get(Node::PORT, "data_out");
    auto uc_port = uc_ports[i];
    uc_port <<= data_stream;
  }

  auto code = vhdl::Declarator::Generate(Cast<Graph>(uc));
  //auto code = vhdl::Declarator::Generate(Cast<Graph>(BusReadArbiter()));
  std::cout << code.str();

  dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

}