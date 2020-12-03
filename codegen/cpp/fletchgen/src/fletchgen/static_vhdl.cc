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

#include "fletchgen/static_vhdl.h"

#include <cmrc/cmrc.hpp>
#include <fstream>
#include <algorithm>
#include <sys/stat.h>
#include <sys/types.h>

CMRC_DECLARE(fletchgen);

namespace fletchgen {

void write_static_vhdl(const std::string &real_dir, const std::string &emb_dir) {
  mkdir(real_dir.c_str(), 0777);
  for (const auto &dirent : cmrc::fletchgen::get_filesystem().iterate_directory(emb_dir)) {
    if (dirent.is_file()) {
      std::ofstream real_file;
      real_file.open(real_dir + "/" + dirent.filename());
      std::ostream_iterator<char> out_it{real_file};
      auto emb_file = cmrc::fletchgen::get_filesystem().open(emb_dir + "/" + dirent.filename());
      std::copy(emb_file.cbegin(), emb_file.cend(), out_it);
      real_file.close();
    } else {
      write_static_vhdl(real_dir + "/" + dirent.filename(), emb_dir + "/" + dirent.filename());
    }
  }
}

}  // namespace fletchgen
