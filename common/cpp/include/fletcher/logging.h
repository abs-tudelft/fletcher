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
#include <cstdlib>

#ifdef FLETCHER_USE_ARROW_LOGGING
/*
 * Use Arrow's logging facilities
 */
#include <arrow/util/logging.h>

// Logging Macros
#define FLETCHER_LOG_INTERNAL(level) ::arrow::util::ArrowLog(__FILE__, __LINE__, level)
#define FLETCHER_LOG(level, msg) FLETCHER_LOG_INTERNAL(fletcher::FLETCHER_LOG_##level) << msg

// Logging levels
constexpr arrow::util::ArrowLogLevel FLETCHER_LOG_DEBUG = arrow::util::ArrowLogLevel::ARROW_DEBUG;
constexpr arrow::util::ArrowLogLevel FLETCHER_LOG_INFO = arrow::util::ArrowLogLevel::ARROW_INFO;
constexpr arrow::util::ArrowLogLevel FLETCHER_LOG_WARNING = arrow::util::ArrowLogLevel::ARROW_WARNING;
constexpr arrow::util::ArrowLogLevel FLETCHER_LOG_ERROR = arrow::util::ArrowLogLevel::ARROW_ERROR;
constexpr arrow::util::ArrowLogLevel FLETCHER_LOG_FATAL = arrow::util::ArrowLogLevel::ARROW_FATAL;

namespace fletcher {

using LogLevel = arrow::util::ArrowLogLevel;

inline void StartLogging(const std::string &app_name, LogLevel level, const std::string &file_name) {
  arrow::util::ArrowLog::StartArrowLog(app_name, level, file_name);
}

inline void StopLogging() {
  arrow::util::ArrowLog::ShutDownArrowLog();
}

}  // namespace fletcher

#else
/*
 * Use stdout to log
 */
#include <iostream>

// Default logging
constexpr int FLETCHER_LOG_DEBUG = -1;
constexpr int FLETCHER_LOG_INFO = 0;
constexpr int FLETCHER_LOG_WARNING = 1;
constexpr int FLETCHER_LOG_ERROR = 2;
constexpr int FLETCHER_LOG_FATAL = 3;

#ifndef NDEBUG
#define FLETCHER_LOG(level, msg) \
  if (FLETCHER_LOG_##level > FLETCHER_LOG_WARNING) {                      \
    std::cerr << "[" + fletcher::level2str(FLETCHER_LOG_##level) + "]: "  \
              << msg                                                      \
              << std::endl;                                               \
    std::exit(-1);                                                        \
  } else {                                                                \
    std::cout << "[" << fletcher::level2str(FLETCHER_LOG_##level) + "]: " \
              << msg                                                      \
              << std::endl;                                               \
  }                                                                       \
(void)0
// ^ prevent empty statement linting errors
#else
#define FLETCHER_LOG(level, msg)                                          \
if (FLETCHER_LOG_##level > FLETCHER_LOG_WARNING) {                        \
    std::cerr << "[" + fletcher::level2str(FLETCHER_LOG_##level) + "]: "  \
              << msg                                                      \
              << std::endl;                                               \
    std::exit(-1);                                                        \
  } else if (FLETCHER_LOG_##level > FLETCHER_LOG_DEBUG) {                 \
    std::cout << "[" << fletcher::level2str(FLETCHER_LOG_##level) + "]: " \
              << msg                                                      \
              << std::endl;                                               \
  }                                                                       \
(void)0
// ^ prevent empty statement linting errors
#endif

namespace fletcher {

using LogLevel = int;

inline std::string level2str(int level) {
  switch (level) {
    default: return "DEBUG";
    case 0: return "INFO ";
    case 1: return "WARN ";
    case 2: return "ERROR";
    case 3: return "FATAL";
  }
}

inline void StartLogging(const std::string &app_name, LogLevel level, const std::string &file_name) {
  // No init required, but prevent compiler warnings by pretending to use the arguments.
  (void) app_name;
  (void) level;
  (void) file_name;
}

inline void StopLogging() {
  // No shutdown required.
}

}  // namespace fletcher
#endif
