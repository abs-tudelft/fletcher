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

#include "stream.h"
#include "column-wrapper.h"

namespace fletchgen {

class ColumnWrapper;

class UserCore : public StreamComponent, public ChildOf<ColumnWrapper> {
 public:
  UserCore(std::string name,
           ColumnWrapper *parent,
           int num_addr_regs,
           int num_user_regs);

  void addUserStreams(std::vector<std::shared_ptr<Column>> column_instances);

  Port *start() { return ctrl_start_.get(); }

  Port *stop() { return ctrl_stop_.get(); }

  Port *reset() { return ctrl_reset_.get(); }

  Port *idle() { return ctrl_idle_.get(); }

  Port *busy() { return ctrl_busy_.get(); }

  Port *done() { return ctrl_done_.get(); }

  Port *user_regs_in() { return rin_.get(); }

  Port *user_regs_out() { return rout_.get(); }

  Port *user_regs_out_en() { return route_.get(); }

  int num_addr_regs() { return num_addr_regs_; }

  int num_user_regs() { return num_user_regs_; }

  std::vector<Buffer *> buffers() { return ptrvec(buffers_); }

 private:
  std::vector<std::shared_ptr<Buffer>> buffers_;
  int num_addr_regs_;
  int num_user_regs_;
  std::shared_ptr<GeneralPort> ctrl_start_;
  std::shared_ptr<GeneralPort> ctrl_stop_;
  std::shared_ptr<GeneralPort> ctrl_reset_;
  std::shared_ptr<GeneralPort> ctrl_idle_;
  std::shared_ptr<GeneralPort> ctrl_busy_;
  std::shared_ptr<GeneralPort> ctrl_done_;

  std::shared_ptr<GeneralPort> rin_;
  std::shared_ptr<GeneralPort> rout_;
  std::shared_ptr<GeneralPort> route_;
};

}