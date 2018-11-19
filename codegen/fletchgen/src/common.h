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
#include <map>
#include <vector>
#include <algorithm>
#include <memory>
#include <arrow/type.h>
#include <arrow/buffer.h>
#include <arrow/ipc/api.h>
#include <arrow/io/api.h>
#include <iostream>

#include "./constants.h"
#include "./meta.h"
#include "./logging.h"

namespace fletchgen {

// Forward decl.
class ColumnWrapper;
namespace config {
struct Config;
}

/// @brief Class to hold names of Arrow buffers
class Buffer : public ChildOf<Buffer> {
 public:
  /**
   * @brief Create a new buffer.
   * @param name The name of the buffer.
   * @param parent The parent buffer, if any (optional)
   */
  explicit Buffer(std::string name, Buffer *parent = nullptr) : ChildOf(parent), _name(std::move(name)) {}

  std::string name() { return _name; }

 private:
  std::string _name;
};

/// @brief Convert a vector of shared pointers to a vector of normal pointers.
template<class T>
std::vector<T *> ptrvec(std::vector<std::shared_ptr<T>> vec) {
  std::vector<T *> ret;
  for (const auto &e : vec) {
    ret.push_back(e.get());
  }
  return ret;
}

/**
 * Generate a VHDL wrapper on an output stream.
 * @param schema The schema to base the wrapper on.
 * @return The column wrapper
 */
std::shared_ptr<ColumnWrapper> generateColumnWrapper(const std::vector<std::ostream *> &outputs,
                                                     const std::vector<std::shared_ptr<arrow::Schema>> &schema,
                                                     const std::string &acc_name,
                                                     const std::string &wrap_name,
                                                     const std::vector<config::Config> &cfgs);

/// @brief Split a string \p str by delimeter \p delim and return a vector of strings.
std::vector<std::string> split(const std::string &str, char delim = ',');

}  // namespace fletchgen
