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

namespace cerata {

// Default logging
constexpr int CERATA_LOG_DEBUG = -1;
constexpr int CERATA_LOG_INFO = 0;
constexpr int CERATA_LOG_WARNING = 1;
constexpr int CERATA_LOG_ERROR = 2;
constexpr int CERATA_LOG_FATAL = 3;
using LogLevel = int;

class Logger {
 public:
  /// Signature of the callback function.
  using CallbackSignature = void(LogLevel, const std::string &, char const *, char const *, int);

  /// @brief Enable the logger. Can only be done after the callback function was set.
  inline void enable(std::function<CallbackSignature> callback) {
    callback_ = callback;
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

inline Logger &logger() {
  static Logger l;
  return l;
}

#define CERATA_LOG(level, msg) logger().write(CERATA_LOG_##level, msg,  __FUNCTION__, __FILE__, __LINE__)

}