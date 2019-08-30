#include <utility>

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
#include <functional>
#include <string>

namespace cerata {

// Log levels.

/// Type used for the logging level.
using LogLevel = int;

constexpr LogLevel CERATA_LOG_DEBUG = -1;    ///< Debug level
constexpr LogLevel CERATA_LOG_INFO = 0;      ///< Information level
constexpr LogLevel CERATA_LOG_WARNING = 1;   ///< Warning level
constexpr LogLevel CERATA_LOG_ERROR = 2;     ///< Error level
constexpr LogLevel CERATA_LOG_FATAL = 3;     ///< Fatal level; tool should exit.

/// Logger class.
class Logger {
 public:
  /// Signature of the callback function.
  using CallbackSignature = void(LogLevel, const std::string &, char const *, char const *, int);

  /// @brief Enable the logger. Can only be done after the callback function was set.
  inline void enable(std::function<CallbackSignature> callback) {
    callback_ = std::move(callback);
  }

  /// @brief Return true if callback was set, false otherwise.
  inline bool IsEnabled() { return callback_ ? true : false; }

  /// @brief Write something using the logging callback function.
  inline void write(LogLevel level,
                    std::string const &message,
                    char const *source_function,
                    char const *source_file,
                    int line_number) {
    if (callback_) {
      callback_(level, message, source_function, source_file, line_number);
    }
  }

 private:
  /// @brief Callback function for Cerata logging
  std::function<void(LogLevel, const std::string &, char const *, char const *, int)> callback_;
};

/// Return the global Cerata logger.
inline Logger &logger() {
  static Logger l;
  return l;
}

#define CERATA_LOG(level, msg) \
if (CERATA_LOG_##level == CERATA_LOG_FATAL) { \
  throw std::runtime_error(std::string(__FILE__) + ":" \
                         + std::to_string(__LINE__) + ":" \
                         + std::string(__FUNCTION__) + ": " + (msg)); \
} else {  \
  logger().write(CERATA_LOG_##level, msg,  __FUNCTION__, __FILE__, __LINE__); \
} \
(void)0

}  // namespace cerata
