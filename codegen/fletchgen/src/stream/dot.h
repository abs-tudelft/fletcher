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

#include "./components.h"

namespace fletchgen {
namespace dot {

using fletchgen::stream::Port;
using fletchgen::stream::Type;
using fletchgen::stream::Vector;
using fletchgen::stream::Signed;
using fletchgen::stream::Unsigned;
using fletchgen::stream::Record;
using fletchgen::stream::Parameter;
using fletchgen::stream::ComponentType;
using fletchgen::stream::Component;
using fletchgen::stream::Edge;
using fletchgen::stream::Node;

class Grapher {
 public:
  static std::string Edges(const std::shared_ptr<Component> &comp);
  static std::string Nodes(const std::shared_ptr<Component> &comp);
};

}  // namespace dot
}  // namespace fletchgen
