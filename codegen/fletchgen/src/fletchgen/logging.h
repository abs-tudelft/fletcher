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

#include <arrow/util/logging.h>

/**
 * Wrap around Arrow's logging facility
 * We use Arrows logging for Fletchgen as well, because Arrow is a hard dependency for this tool anyway.
 */

// Logging Macros
#define LOG_INTERNAL(level) ::arrow::util::ArrowLog(__FILE__, __LINE__, level)
#define LOG(level) LOG_INTERNAL(::arrow::util::ArrowLogLevel::ARROW_##level)

namespace fletchgen::logging {

// Logging levels
constexpr arrow::util::ArrowLogLevel LOG_DEBUG = arrow::util::ArrowLogLevel::ARROW_DEBUG;
constexpr arrow::util::ArrowLogLevel LOG_INFO = arrow::util::ArrowLogLevel::ARROW_INFO;
constexpr arrow::util::ArrowLogLevel LOG_WARNING = arrow::util::ArrowLogLevel::ARROW_WARNING;
constexpr arrow::util::ArrowLogLevel LOG_ERROR = arrow::util::ArrowLogLevel::ARROW_ERROR;
constexpr arrow::util::ArrowLogLevel LOG_FATAL = arrow::util::ArrowLogLevel::ARROW_FATAL;

using LogLevel = arrow::util::ArrowLogLevel;

/**
 * @brief Start logging.
 * @param app_name  Name of the application.
 * @param file_name Name of the log file.
 */
void StartLogging(const std::string &app_name, LogLevel level, const std::string &file_name) {
  arrow::util::ArrowLog::StartArrowLog(app_name, level, file_name);
}

/**
 * @brief Stop logging.
 */
void StopLogging() {
  arrow::util::ArrowLog::ShutDownArrowLog();
}

}