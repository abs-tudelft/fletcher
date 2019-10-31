// Copyright 2018-2019 Delft University of Technology
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

#include <gtest/gtest.h>
#include <cerata/api.h>
#include <string>

#include "fletchgen/utils.h"
#include "fletchgen/profiler.h"
#include "fletchgen/test_utils.h"
#include "fletchgen/basic_types.h"

namespace fletchgen {

TEST(Profiler, Connect) {
  cerata::logger().enable(fletchgen::LogCerata);
  cerata::default_component_pool()->Clear();

  auto stream_type = cerata::stream("test_stream", "data", cerata::vector(8));
  auto stream_port_in = port("input", stream_type, Port::IN);
  auto stream_port_out = port("output", stream_type, Port::OUT);
  auto crp = port("bcd", cr(), Port::IN);
  auto top = cerata::component("top", {crp, stream_port_in, stream_port_out});
  auto stream_sig =
      cerata::AttachSignalToNode(top.get(), stream_port_out.get(), top->inst_to_comp_map(), "Pr_" + stream_port_out->name());

  EnableStreamProfiling(top.get(), {stream_sig});

  GenerateTestAll(top);
}

}  // namespace fletchgen
