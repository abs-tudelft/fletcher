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
                                                     const std::shared_ptr<arrow::Schema> &schema,
                                                     const std::string &acc_name,
                                                     const std::string &wrap_name,
                                                     config::Config cfg) {
  LOGD("Arrow Schema:");
  LOGD(schema->ToString());

  LOGD("Fletcher Wrapper Generation:");
  auto col_wrapper = std::make_shared<ColumnWrapper>(schema, wrap_name, acc_name, cfg);

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

}//namespace fletchgen