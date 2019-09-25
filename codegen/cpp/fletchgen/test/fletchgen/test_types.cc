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

#include <cerata/api.h>
#include <gtest/gtest.h>
#include <memory>

#include "fletcher/test_schemas.h"

#include "fletchgen/array.h"
#include "fletchgen/recordbatch.h"

namespace fletchgen {

TEST(Types, TypeMapper) {
  // Test automated type mapper from ArrayReader/Writer to kernel stream
  auto schema = fletcher::GetPrimReadSchema();
  auto fletcher_schema = FletcherSchema::Make(schema);

  auto arrow_port = FieldPort::MakeArrowPort(fletcher_schema, schema->field(0), fletcher_schema->mode(), true);
  auto arrow_type = arrow_port->type();
  auto top = Component::Make("top", {arrow_port});

  auto array_port = cerata::Port::Make("out", read_data(), Port::Dir::OUT);
  auto array_type = array_port->type();
  auto array = Component::Make("array_mock", {array_port});

  auto mapper = GetStreamTypeMapper(arrow_type, array_type);
  arrow_type->AddMapper(mapper);

  auto array_inst = top->AddInstanceOf(array.get());
  std::static_pointer_cast<Node>(arrow_port) <<= array_inst->port("out");

  std::cout << cerata::vhdl::Design(top).Generate().ToString();
}

}  // namespace fletchgen
