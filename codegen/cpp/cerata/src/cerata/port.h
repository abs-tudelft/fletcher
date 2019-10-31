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
#include <string>

#include "cerata/node.h"

namespace cerata {

/**
 * @brief A terminator structure to enable terminator sanity checks.
 */
class Term {
 public:
  /// Terminator direction.
  enum Dir { IN, OUT };

  /// @brief Return the inverse of a direction.
  static Dir Reverse(Dir dir);

  /// @brief Return the direction of this terminator.
  [[nodiscard]] inline Dir dir() const { return dir_; }

  /// @brief Construct a new Term.
  explicit Term(Dir dir) : dir_(dir) {}

  /// @brief Return true if this Term is an input, false otherwise.
  inline bool IsInput() { return dir_ == IN; }
  /// @brief Return true if this Term is an output, false otherwise.
  inline bool IsOutput() { return dir_ == OUT; }

  /// @brief Convert a Dir to a human-readable string.
  static std::string str(Dir dir);

 protected:
  /// The direction of this terminator.
  Dir dir_;
};

/**
 * @brief A port is a terminator node on a graph
 */
class Port : public NormalNode, public Synchronous, public Term {
 public:
  /// @brief Construct a new port.
  Port(std::string name, std::shared_ptr<Type> type, Term::Dir dir, std::shared_ptr<ClockDomain> domain);
  /// @brief Deep-copy the port.
  std::shared_ptr<Object> Copy() const override;
  /// @brief Invert the direction of this port. Removes any edges.
  Port &Reverse();

  std::string ToString() const override;
};

/// @brief Make a new port with some name, type and direction.
std::shared_ptr<Port> port(const std::string &name,
                           const std::shared_ptr<Type> &type,
                           Term::Dir dir,
                           const std::shared_ptr<ClockDomain> &domain = default_domain());
/// @brief Make a new port. The name will be derived from the name of the type.
std::shared_ptr<Port> port(const std::shared_ptr<Type> &type,
                           Term::Dir dir,
                           const std::shared_ptr<ClockDomain> &domain = default_domain());

}  // namespace cerata
