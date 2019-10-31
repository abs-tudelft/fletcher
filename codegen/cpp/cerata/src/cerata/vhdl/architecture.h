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

#pragma once

#include <memory>

#include "cerata/graph.h"
#include "cerata/vhdl/declaration.h"
#include "cerata/vhdl/block.h"

namespace cerata::vhdl {

/// Architecture generators.
struct Arch {
  /// @brief Generate the VHDL architecture of a component.
  static MultiBlock Generate(const Component &comp);
  /// @brief Generate the VHDL signal assignments.
  static Block Generate(const Signal &sig, int indent = 0);
  /// @brief Generate the VHDL port assignments.
  static Block Generate(const Port &port, int indent = 0);
  /// @brief Generate the VHDL signal array assignments inside a component.
  static Block Generate(const SignalArray &sig_array, int indent = 0);
  /// @brief Generate component declarations within VHDL architecture declarations block.
  static MultiBlock GenerateCompDeclarations(const Component &comp, int indent = 0);
  /// @brief Generate component instantiations within VHDL architecture concurrent statements block.
  static MultiBlock GenerateCompInstantiations(const Component &comp, int indent = 0);

  /// @brief Generate relevant VHDL component declarations of all Cerata instances.
  template<typename T>
  static Block GenerateNodeDeclarations(const Component &comp, int indent = 0) {
    Block result(indent);
    auto objs = comp.GetAll<T>();
    for (const auto &o : objs) {
      auto decl = Decl::Generate(*o, 1);
      result << decl;
      if (decl.lines.size() > 1) {
        result << Line();
      }
    }
    return result.AppendBlankLineIfNotEmpty();
  }

  /// @brief Generate relevant VHDL signal assignments of all Cerata nodes.
  template<typename T>
  static Block GenerateAssignments(const Component &comp, int indent = 0) {
    Block result(indent);
    auto objs = comp.GetAll<T>();
    for (const auto &o : objs) {
      auto assignment = Arch::Generate(*o, 1);
      result << assignment;
      if (assignment.lines.size() > 1) {
        result << Line();
      }
    }
    return result.AppendBlankLineIfNotEmpty();
  }
};

}  // namespace cerata::vhdl
