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

#include <string>
#include <map>

#include "common.h"
#include "column-wrapper.h"
#include "vhdt/vhdt.h"

namespace fletchgen {

std::shared_ptr<ColumnWrapper> generateColumnWrapper(const std::vector<std::ostream *> &outputs,
                                                     const std::vector<std::shared_ptr<arrow::Schema>> &schemas,
                                                     const std::string &acc_name,
                                                     const std::string &wrap_name,
                                                     const std::vector<config::Config> &cfgs) {
  LOGD("Fletcher Wrapper Generation:");
  auto col_wrapper = std::make_shared<ColumnWrapper>(schemas, wrap_name, acc_name, cfgs);

  auto ent = col_wrapper->entity()->toVHDL();
  auto arch = col_wrapper->architecture()->toVHDL();

  std::cerr.flush();

  for (auto &o : outputs) {
    o->flush();
    *o << ce::COPYRIGHT_NOTICE << std::endl;
    *o << ce::GENERATED_NOTICE << std::endl;
    *o << ce::DEFAULT_LIBS << std::endl;
    *o << ent << std::endl;
    *o << arch << std::endl;
  }

  return col_wrapper;
}

std::vector<std::string> split(const std::string &str, const char delim) {
  std::vector<std::string> strings;
  std::istringstream input;
  input.str(str);
  for (std::string line; std::getline(input, line, ',');) {
    strings.push_back(line);
  }
  return strings;
}

}  // namespace fletchgen
