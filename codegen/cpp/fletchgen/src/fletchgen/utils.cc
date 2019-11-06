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

#include "fletchgen/utils.h"

#include <fletcher/common.h>
#include <cerata/api.h>
#include <cstdlib>

#include "fletchgen_config/config.h"

namespace fletchgen {

std::string GetProgramName(char *argv0) {
  auto arg = std::string(argv0);
  size_t pos = arg.rfind('\\');
  if (pos != std::string::npos) {
    return arg.substr(pos + 1);
  } else {
    return "fletchgen";
  }
}

cerata::Port::Dir mode2dir(fletcher::Mode mode) {
  if (mode == fletcher::Mode::READ) {
    return cerata::Port::Dir::IN;
  } else {
    return cerata::Port::Dir::OUT;
  }
}

void LogCerata(cerata::LogLevel level,
               std::string const &message,
               char const *source_function,
               char const *source_file,
               int line_number) {
  switch (level) {
    default: {
      FLETCHER_LOG(DEBUG, message);
      return;
    }
    case cerata::CERATA_LOG_INFO: {
      FLETCHER_LOG(INFO, message);
      return;
    }
    case cerata::CERATA_LOG_WARNING: {
      FLETCHER_LOG(WARNING, message);
      return;
    }
    case cerata::CERATA_LOG_ERROR: {
      FLETCHER_LOG(ERROR, message);
      std::abort();
    }
    case cerata::CERATA_LOG_FATAL: {
      FLETCHER_LOG(FATAL, message);
      std::abort();
    }
  }
}

std::string version() {
  return "fletchgen " + std::to_string(FLETCHGEN_VERSION_MAJOR)
      + "." + std::to_string(FLETCHGEN_VERSION_MINOR)
      + "." + std::to_string(FLETCHGEN_VERSION_PATCH);
}

}  // namespace fletchgen
