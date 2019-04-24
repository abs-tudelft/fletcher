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

#include <utility>
#include <string>

#include "./vhdl/vhdl.h"
#include "./usercore.h"

using std::make_shared;

using vhdl::t;

namespace fletchgen {

UserCore::UserCore(std::string name, ColumnWrapper *parent, int num_addr_regs, int num_user_regs)
    : StreamComponent(std::move(name)), ChildOf(parent), num_addr_regs_(num_addr_regs), num_user_regs_(num_user_regs) {
  int group = 0xC0FFEE;

  /* Global ports */
  // Accelerator clock
  auto aclk = make_shared<GeneralPort>(ce::ACC_CLK, GP::ACC_CLK, Dir::IN);
  auto areset = make_shared<GeneralPort>(ce::ACC_RST, GP::ACC_RESET, Dir::IN);

  entity()->addPort(aclk, group);
  entity()->addPort(areset, group);
  group++;

  /* Control signals */
  ctrl_start_ = make_shared<GeneralPort>("ctrl_start", GP::SIG, Dir::IN);
  ctrl_stop_ = make_shared<GeneralPort>("ctrl_stop", GP::SIG, Dir::IN);
  ctrl_reset_ = make_shared<GeneralPort>("ctrl_reset", GP::SIG, Dir::IN);
  ctrl_idle_ = make_shared<GeneralPort>("ctrl_idle", GP::SIG, Dir::OUT);
  ctrl_busy_ = make_shared<GeneralPort>("ctrl_busy", GP::SIG, Dir::OUT);
  ctrl_done_ = make_shared<GeneralPort>("ctrl_done", GP::SIG, Dir::OUT);
  entity()->addPort(ctrl_start_, group);
  entity()->addPort(ctrl_stop_, group);
  entity()->addPort(ctrl_reset_, group);
  entity()->addPort(ctrl_idle_, group);
  entity()->addPort(ctrl_busy_, group);
  entity()->addPort(ctrl_done_, group);
  group++;

  /* User streams */
  // Will be inserted with group they already have
  auto columns = parent->column_instances();
  if (!columns.empty()) {
    addUserStreams(columns);
    addStreamPorts();
  } else {
    throw std::runtime_error("Wrapper parent of UserCore contains no Array instances.");
  }

  setComment(t(1) + "-- Hardware Accelerated Function component.\n" +
      t(1) + "-- This component should be implemented by the user.\n");

  /* First and last index registers */
  auto p_idx_first = make_shared<GeneralPort>(nameFrom({"idx", "first"}), GP::REG_IDX, Dir::IN, Value(ce::REG_WIDTH));
  auto p_idx_last = make_shared<GeneralPort>(nameFrom({"idx", "last"}), GP::REG_IDX, Dir::IN, Value(ce::REG_WIDTH));
  entity()->addPort(p_idx_first, group);
  entity()->addPort(p_idx_last, group);

  /* Return registers */
  auto r0 = make_shared<GeneralPort>(nameFrom({"reg", "return0"}), GP::REG_RETURN, Dir::OUT, Value(ce::REG_WIDTH));
  auto r1 = make_shared<GeneralPort>(nameFrom({"reg", "return1"}), GP::REG_RETURN, Dir::OUT, Value(ce::REG_WIDTH));
  entity()->addPort(r0, group);
  entity()->addPort(r1, group);
  group++;

  /* Buffer Address registers */
  // Get all buffers
  for (const auto &c : columns) {
    auto cbufs = c->getBuffers();
    buffers_.insert(buffers_.end(), cbufs.begin(), cbufs.end());
  }
  for (const auto &b : buffers_) {
    auto bufport =
        make_shared<GeneralPort>(nameFrom({"reg", b->name(), "addr"}), GP::REG_ADDR, Dir::IN, Value("BUS_ADDR_WIDTH"));
    entity()->addPort(bufport, group);
  }

  /* User registers */
  if (num_user_regs_ > 0) {
    entity()->addGeneric(make_shared<vhdl::Generic>(ce::NUM_USER_REGS, "natural", Value(num_user_regs)));

    rin_ = make_shared<GeneralPort>("regs_in", GP::REG_ADDR, Dir::IN, Value(ce::NUM_USER_REGS) * Value(ce::REG_WIDTH));
    rout_ =
        make_shared<GeneralPort>("regs_out", GP::REG_USER, Dir::OUT, Value(ce::NUM_USER_REGS) * Value(ce::REG_WIDTH));
    route_ = make_shared<GeneralPort>("regs_out_en", GP::REG_USER, Dir::OUT, Value(ce::NUM_USER_REGS));
    entity()->addPort(rin_, group);
    entity()->addPort(rout_, group);
    entity()->addPort(route_, group);
    group++;
  }

  /* Generics */
  entity()->addGeneric(make_shared<vhdl::Generic>(ce::TAG_WIDTH, "natural", Value(ce::TAG_WIDTH)));
  entity()->addGeneric(make_shared<vhdl::Generic>(ce::BUS_ADDR_WIDTH, "natural", Value(ce::BUS_ADDR_WIDTH)));
  entity()->addGeneric(make_shared<vhdl::Generic>(ce::INDEX_WIDTH, "natural", Value(ce::INDEX_WIDTH)));
  entity()->addGeneric(make_shared<vhdl::Generic>(ce::REG_WIDTH, "natural", Value(ce::REG_WIDTH)));
}

void UserCore::addUserStreams(std::vector<std::shared_ptr<fletchgen::Column>> column_instances) {
  for (const auto &c : column_instances) {
    // Only Arrow streams should be copied over to the ColumnWrapper.
    auto uds = c->getArrowStreams();

    // Invert each stream direction and append the vector.
    for (const auto &s : uds) {
      s->invert();
      _streams.push_back(s);
    }

    // Append the UserCommandStream for each column
    auto cmds = c->generateUserCommandStream();
    cmds->invert();
    appendStream(cmds);

    auto us = c->generateUserUnlockStream();
    us->invert();
    appendStream(us);
  }
}

}  // namespace fletchgen
