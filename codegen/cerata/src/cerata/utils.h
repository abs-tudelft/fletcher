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
#include <memory>
#include <utility>
#include <deque>
#include <algorithm>
#include <optional>
#include <fstream>

namespace cerata {

/**
 * @brief Structure to name objects.
 */
struct Named {
 public:
  /// @brief Named constructor.
  explicit Named(std::string name) : name_(std::move(name)) {}
  /// @brief Return the name of the object.
  std::string name() const { return name_; }
  /// @brief Change the name of the object.
  void SetName(std::string name) { name_ = std::move(name); }
 private:
  /// @brief The object name.
  std::string name_;
};

/// @brief Return true if list contains item, false otherwise.
template<typename T>
bool contains(const std::deque<std::shared_ptr<T>> &list, const std::shared_ptr<T> &item) {
  return std::find(std::begin(list), std::end(list), item) != std::end(list);
}

/// @brief Return true if list contains item, false otherwise.
template<typename T>
bool contains(const std::deque<T *> &list, T *item) {
  return std::find(std::begin(list), std::end(list), item) != std::end(list);
}

/// @brief Return true if list contains item, false otherwise.
template<typename T>
bool contains(const std::deque<const T *> &list, const T *item) {
  return std::find(std::begin(list), std::end(list), item) != std::end(list);
}

/// @brief Append list b to list a.
template<typename T>
void append(std::deque<std::shared_ptr<T>> *list_a, const std::deque<std::shared_ptr<T>> &list_b) {
  list_a->insert(list_a->end(), list_b.begin(), list_b.end());
}
/**
 * @brief Remove an item from a deque, returning false if it was not in the deque, true otherwise.
 * @tparam T    The type of the item
 * @param list  The deque
 * @param item  The item to remove
 * @return      True if item was in list and got removed, false otherwise.
 */
template<typename T>
bool remove(std::deque<std::shared_ptr<T>> *list, const std::shared_ptr<T> &item) {
  auto it = std::find(std::begin(*list), std::end(*list), item);
  if (it != std::end(*list)) {
    list->erase(it);
    return true;
  } else {
    return false;
  }
}

void CreateDir(const std::string& dir_name);

bool FileExists (const std::string& name);

}  // namespace cerata
