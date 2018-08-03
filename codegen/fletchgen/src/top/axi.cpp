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

#include "axi.h"

#include "../vhdt/vhdt.h"

namespace axi {

std::string generateAXITop(const std::shared_ptr<fletchgen::ColumnWrapper> &col_wrapper,
                           const std::vector<std::ostream *> &outputs) {
  const char *fhwd = std::getenv("FLETCHER_HARDWARE_DIR");
  if (fhwd == nullptr) {
    throw std::runtime_error("Environment variable FLETCHER_HARDWARE_DIR not set. Please source env.sh.");
  }

  fletchgen::VHDLTemplate t(std::string(fhwd) + "/vhdl/axi/axi_top.vhdt");

  t.replace("NUM_ARROW_BUFFERS", col_wrapper->countBuffers());
  t.replace("NUM_REGS", col_wrapper->countRegisters());
  t.replace("NUM_USER_REGS", col_wrapper->user_regs());

  // Do not change this order, TODO: fix this in replacement code
  t.replace("FLETCHER_WRAPPER_NAME", col_wrapper->entity()->name());
  t.replace("FLETCHER_WRAPPER_INST_NAME", nameFrom({col_wrapper->entity()->name(), "inst"}));

  for (auto &o : outputs) {
    o->flush();
    *o << t.toString();
  }

  return t.toString();
}

} //namespace axi