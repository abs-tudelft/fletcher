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

#include "dag/transform/compress.h"

#include <string>
#include <vector>

#include "dag/dag.h"

namespace dag::transform {

Transform DecompressSnappyBuffered() {
  Transform result;
  result.name = "SnappyDecompressBuffered";
  result += in("in", binary());
  result += out("out", binary());
  return result;
}

Transform DecompressSnappy() {
  Transform result;
  result.name = "SnappyDecompress";
  result += in("in", binary());
  result += out("out", binary());
  return result;
}

}
