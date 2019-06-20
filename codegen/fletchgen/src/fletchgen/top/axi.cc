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

#include "fletchgen/top/axi.h"

#include <cerata/api.h>
#include <memory>

#include "fletchgen/mantle.h"

namespace fletchgen::top {

using cerata::vhdl::Template;

std::string GenerateAXITop(const std::shared_ptr<Mantle> &mantle, const std::vector<std::ostream *> &outputs) {
  const char *fhwd = std::getenv("FLETCHER_HARDWARE_DIR");
  if (fhwd == nullptr) {
    throw std::runtime_error("Environment variable FLETCHER_HARDWARE_DIR not set. Please source env.sh.");
  }

  Template t(std::string(fhwd) + "/axi/axi_top.vhdt");

  // Bus properties
  t.Replace("BUS_ADDR_WIDTH", 64);
  t.Replace("BUS_DATA_WIDTH", 512);
  t.Replace("BUS_STROBE_WIDTH", 512 / 8);
  t.Replace("BUS_LEN_WIDTH", 8);
  t.Replace("BUS_BURST_STEP_LEN", 1);
  t.Replace("BUS_BURST_MAX_LEN", 64);

  // MMIO properties
  t.Replace("MMIO_ADDR_WIDTH", 32);
  t.Replace("MMIO_DATA_WIDTH", 32);

  // Do not change this order, TODO: fix this in replacement code
  t.Replace("FLETCHER_WRAPPER_NAME", mantle->name());
  t.Replace("FLETCHER_WRAPPER_INST_NAME", mantle->name() + "_inst");

  for (auto &o : outputs) {
    o->flush();
    *o << t.ToString();
  }

  return t.ToString();
}

}  // namespace fletchgen::top
