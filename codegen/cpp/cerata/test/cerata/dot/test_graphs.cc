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

#include <gtest/gtest.h>
#include <cerata/api.h>

#include "cerata/test_designs.h"

namespace cerata {

TEST(Dot, Component) {
  default_component_pool()->Clear();
  // Get component
  auto top = GetAllPortTypesComponent();
  // Generate graph
  dot::Grapher dot;
  dot.GenFile(*top, "Dot_Component.dot");
}

TEST(Dot, Example) {
  default_component_pool()->Clear();
  auto top = GetExampleDesign();
  dot::Grapher dot;
  dot.GenFile(*top, "Dot_Example.dot");
}

TEST(Dot, Expansion) {
  default_component_pool()->Clear();
  auto top = GetTypeExpansionComponent();
  dot::Grapher dot;
  dot.style.config = dot::Config::all();
  dot.GenFile(*top, "Dot_Expansion.dot");
}

}  // namespace cerata
