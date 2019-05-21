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

#include <iostream>

namespace cerata {

// Default logging
constexpr int CERATA_LOG_DEBUG = -1;
constexpr int CERATA_LOG_INFO = 0;
constexpr int CERATA_LOG_WARNING = 1;
constexpr int CERATA_LOG_ERROR = 2;
constexpr int CERATA_LOG_FATAL = 3;
using LogLevel = int;

#define CERATA_LOG(level, msg) std::cout << "[" << level2str(CERATA_LOG_##level) + "]: " << msg << std::endl

inline std::string level2str(int level) {
  switch (level) {
    default: return "D";
    case 0: return "I";
    case 1: return "W";
    case 2: return "E";
    case 3: return "F";
  }
}

inline void StartLogging(const std::string &app_name, LogLevel level, const std::string &file_name) {
  // No init required, but prevent compiler warnings by pretending to use the arguments.
  (void)app_name;
  (void)level;
  (void)file_name;
}
inline void StopLogging() {
  // No shutdown required.
}

}