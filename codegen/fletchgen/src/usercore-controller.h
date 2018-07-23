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

#include <string>

#include "vhdl/vhdl.h"

using vhdl::Component;

namespace fletchgen {

class UserCoreController : public Component {
 public:
  UserCoreController();

  Port *status() { return status_.get(); }

  Port *ctrl() { return ctrl_.get(); }

  Port *start() { return start_.get(); }

  Port *stop() { return stop_.get(); }

  Port *reset() { return reset_.get(); }

  Port *idle() { return idle_.get(); }

  Port *busy() { return busy_.get(); }

  Port *done() { return done_.get(); }

 private:
  std::shared_ptr<GeneralPort> status_;
  std::shared_ptr<GeneralPort> ctrl_;
  std::shared_ptr<GeneralPort> start_;
  std::shared_ptr<GeneralPort> stop_;
  std::shared_ptr<GeneralPort> reset_;
  std::shared_ptr<GeneralPort> idle_;
  std::shared_ptr<GeneralPort> busy_;
  std::shared_ptr<GeneralPort> done_;
};

}//namespace fletchgen