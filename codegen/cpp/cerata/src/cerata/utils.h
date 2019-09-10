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
#include <unordered_map>

namespace cerata {

/// @brief Return a human-readable representation of an unordered map of string key-value pairs.
std::string ToString(const std::unordered_map<std::string, std::string> &meta);

/// Convenience structure for anything that is named.
struct Named {
 public:
  /// @brief Named constructor.
  explicit Named(std::string name) : name_(std::move(name)) {}
  /// @brief Return the name of the object.
  std::string name() const { return name_; }
  /// @brief Change the name of the object.
  void SetName(std::string name) { name_ = std::move(name); }

  /// Destructor
  virtual ~Named() = default;
 private:
  /// @brief The object name.
  std::string name_;
};

/// @brief Return true if list contains item, false otherwise.
template<typename T>
bool Contains(const std::deque<std::shared_ptr<T>> &list, const std::shared_ptr<T> &item) {
  return std::find(std::begin(list), std::end(list), item) != std::end(list);
}

/// @brief Return true if list contains item, false otherwise.
template<typename T>
bool Contains(const std::deque<std::weak_ptr<T>> &list, const std::weak_ptr<T> &item) {
  return std::find(std::begin(list), std::end(list), item) != std::end(list);
}

/// @brief Return true if list contains item, false otherwise.
template<typename T>
bool Contains(const std::deque<T *> &list, T *item) {
  return std::find(std::begin(list), std::end(list), item) != std::end(list);
}

/// @brief Append list b to list a.
template<typename T>
void Append(std::deque<std::shared_ptr<T>> *list_a, const std::deque<std::shared_ptr<T>> &list_b) {
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
bool Remove(std::deque<std::shared_ptr<T>> *list, const std::shared_ptr<T> &item) {
  auto it = std::find(std::begin(*list), std::end(*list), item);
  if (it != std::end(*list)) {
    list->erase(it);
    return true;
  } else {
    return false;
  }
}

/**
 * @brief Convert a list of shared pointers to raw pointers.
 * @tparam T    The type of the objects being pointed to.
 * @param list  The list of shared pointers.
 * @return      A list of raw pointers.
 */
template<typename T>
std::deque<T *> ToRawPointers(const std::deque<std::shared_ptr<T>> &list) {
  std::deque<T *> result;
  for (auto &value : list) {
    result.push_back(value.get());
  }
  return result;
}

/**
 * @brief Convert a list of unique pointers to raw pointers.
 * @tparam T    The type of the objects being pointed to.
 * @param list  The list of unique pointers.
 * @return      A list of raw pointers.
 */
template<typename T>
std::deque<T *> ToRawPointers(const std::deque<std::unique_ptr<T>> &list) {
  std::deque<T *> result;
  for (auto &value : list) {
    result.push_back(value.get());
  }
  return result;
}

/// @brief Create a directory.
void CreateDir(const std::string &dir_name);

/// @brief Check if file exists.
bool FileExists(const std::string &name);

}  // namespace cerata
