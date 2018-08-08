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

#include "common.h"
#include "stream.h"

#include "fletcher-streams.h"

namespace fletchgen {

/**
 * @brief A read arbiter component.
 */
class ReadArbiter : public StreamComponent {
 public:
  explicit ReadArbiter(int num_slave_ports = 1);

  std::shared_ptr<ReadRequestStream> slv_rreq() { return slv_rreq_; }

  std::shared_ptr<ReadDataStream> slv_rdat() { return slv_rdat_; }

  std::shared_ptr<ReadRequestStream> mst_rreq() { return mst_rreq_; }

  std::shared_ptr<ReadDataStream> mst_rdat() { return mst_rdat_; }

 private:
  std::shared_ptr<ReadRequestStream> slv_rreq_;
  std::shared_ptr<ReadDataStream> slv_rdat_;
  std::shared_ptr<ReadRequestStream> mst_rreq_;
  std::shared_ptr<ReadDataStream> mst_rdat_;
};

}//namespace fletchgen