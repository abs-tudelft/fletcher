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
#include <memory>

#include "cerata/graphs.h"

namespace cerata {

/**
 * @brief Abstract class to generate language specific output from Graphs
 */
class OutputGenerator {
 public:
  explicit OutputGenerator(std::string root_dir, std::deque<std::shared_ptr<cerata::Graph>> graphs = {});

  /// @brief Add a graph to the list of graphs to generate output for.
  OutputGenerator &AddGraph(std::shared_ptr<cerata::Graph> graph);

  /// @brief Start the output generation.
  virtual void Generate() = 0;

  /// @brief Return the subdirectory this OutputGenerator will generate into.
  virtual std::string subdir() = 0;

 protected:
  std::string root_dir_;
  std::deque<std::shared_ptr<cerata::Graph>> graphs_;
};

} // namespace cerata
