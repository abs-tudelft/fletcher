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

#ifdef LOG_ARROW
/*
 * Use Arrow's logging facilities
 */
#include <arrow/util/logging.h>

namespace fletcher {

// Logging levels
constexpr arrow::util::ArrowLogLevel LOG_DEBUG = arrow::util::ArrowLogLevel::ARROW_DEBUG;
constexpr arrow::util::ArrowLogLevel LOG_INFO = arrow::util::ArrowLogLevel::ARROW_INFO;
constexpr arrow::util::ArrowLogLevel LOG_WARNING = arrow::util::ArrowLogLevel::ARROW_WARNING;
constexpr arrow::util::ArrowLogLevel LOG_ERROR = arrow::util::ArrowLogLevel::ARROW_ERROR;
constexpr arrow::util::ArrowLogLevel LOG_FATAL = arrow::util::ArrowLogLevel::ARROW_FATAL;

// Logging Macros
#define FLETCHER_LOG_INTERNAL(level) ::arrow::util::ArrowLog(__FILE__, __LINE__, level)
#define FLETCHER_LOG(level, msg) FLETCHER_LOG_INTERNAL(::arrow::util::ArrowLogLevel::ARROW_##level) << msg

using LogLevel = arrow::util::ArrowLogLevel;

void StartLogging(const std::string &app_name, LogLevel level, const std::string &file_name) {
  arrow::util::ArrowLog::StartArrowLog(app_name, level, file_name);
}

void StopLogging() {
  arrow::util::ArrowLog::ShutDownArrowLog();
}

} // namespace fletcher

#else
/*
 * Use stdout to log
 */
#include <iostream>

#define FLETCHER_LOG(level, msg) std::cerr << "[" << fletcher::level2str(LOG_##level) + "]: " << msg << std::endl

// Default logging
constexpr int LOG_DEBUG = -1;
constexpr int LOG_INFO = 0;
constexpr int LOG_WARNING = 1;
constexpr int LOG_ERROR = 2;
constexpr int LOG_FATAL = 3;
using LogLevel = int;

namespace fletcher {

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

} // namespace fletcher
#endif
