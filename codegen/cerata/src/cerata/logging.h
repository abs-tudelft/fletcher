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
// Enable logging using Apache Arrows logging facility
#include <arrow/util/logging.h>

// This Cerata logging facility wraps around Arrow's logging facility

// Logging levels
constexpr arrow::util::ArrowLogLevel LOG_DEBUG = arrow::util::ArrowLogLevel::ARROW_DEBUG;
constexpr arrow::util::ArrowLogLevel LOG_INFO = arrow::util::ArrowLogLevel::ARROW_INFO;
constexpr arrow::util::ArrowLogLevel LOG_WARNING = arrow::util::ArrowLogLevel::ARROW_WARNING;
constexpr arrow::util::ArrowLogLevel LOG_ERROR = arrow::util::ArrowLogLevel::ARROW_ERROR;
constexpr arrow::util::ArrowLogLevel LOG_FATAL = arrow::util::ArrowLogLevel::ARROW_FATAL;

// Logging Macros
#define LOG_INTERNAL(level) ::arrow::util::ArrowLog(__FILE__, __LINE__, level)
#define LOG(level, msg) LOG_INTERNAL(::arrow::util::ArrowLogLevel::ARROW_##level) << msg

using LogLevel = arrow::util::ArrowLogLevel;
#else
#include <iostream>
// Default logging
constexpr int LOG_DEBUG = -1;
constexpr int LOG_INFO = 0;
constexpr int LOG_WARNING = 1;
constexpr int LOG_ERROR = 2;
constexpr int LOG_FATAL = 3;
using LogLevel = int;

inline std::string level2str(int level) {
  switch (level) {
    default: return "DEBUG";
    case 0: return "INFO";
    case 1: return "WARNING";
    case 2: return "ERROR";
    case 3: return "FATAL";
  }
}

#define LOG(level, msg) std::cerr << "[" + level2str(LOG_##level) + "]: " << msg << std::endl
#endif

namespace cerata {

/**
 * @brief Start logging.
 * @param app_name  Name of the application.
 * @param file_name Name of the log file.
 */
void StartLogging(const std::string &app_name, LogLevel level, const std::string &file_name);

/**
 * @brief Stop logging.
 */
void StopLogging();

}