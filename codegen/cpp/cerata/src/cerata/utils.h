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

#pragma once

#include <string>
#include <memory>
#include <utility>
#include <vector>
#include <algorithm>
#include <optional>
#include <fstream>
#include <unordered_map>

namespace cerata {

/// @brief Convert string to upper-case.
std::string ToUpper(std::string str);
/// @brief Convert string to lower-case.
std::string ToLower(std::string str);

/// @brief Return a human-readable representation of an unordered map of string key-value pairs.
std::string ToString(const std::unordered_map<std::string, std::string> &meta);

/// Convenience structure for anything that is named. Names are case-sensitive.
struct Named {
 public:
  /// @brief Named constructor.
  explicit Named(std::string name) : name_(std::move(name)) {}
  /// @brief Return the name of the object.
  [[nodiscard]] std::string name() const { return name_; }
  /// @brief Change the name of the object.
  void SetName(std::string name) { name_ = std::move(name); }

  /// Destructor
  virtual ~Named() = default;
 private:
  /// @brief The object name.
  std::string name_;
};

/// @brief Return true if vector contains item, false otherwise.
template<typename T>
bool Contains(const std::vector<std::shared_ptr<T>> &list, const std::shared_ptr<T> &item) {
  return std::find(std::begin(list), std::end(list), item) != std::end(list);
}

/// @brief Return true if vector contains item, false otherwise.
template<typename T>
bool Contains(const std::vector<std::weak_ptr<T>> &list, const std::weak_ptr<T> &item) {
  return std::find(std::begin(list), std::end(list), item) != std::end(list);
}

/// @brief Return true if vector contains item, false otherwise.
template<typename T>
bool Contains(const std::vector<T *> &list, T *item) {
  return std::find(std::begin(list), std::end(list), item) != std::end(list);
}

/// @brief Append list b to list a.
template<typename T>
void Append(std::vector<T> *list_a, const std::vector<T> &list_b) {
  list_a->insert(list_a->end(), list_b.begin(), list_b.end());
}

/// @brief Merge a list of vectors into one vector.
template<typename T>
std::vector<T> Merge(std::initializer_list<std::vector<T>> lists) {
  std::vector<T> result;
  for (const auto &l : lists) {
    result.insert(result.end(), l.begin(), l.end());
  }
  return result;
}

/// @brief Merge a list of unordered maps into one unordered map.
template<typename T, typename U>
std::vector<T> Merge(std::initializer_list<std::unordered_map<T, U>> lists) {
  std::vector<T> result;
  for (const auto &l : lists) {
    result.insert(result.end(), l.begin(), l.end());
  }
  return result;
}

/**
 * @brief Remove an item from a vector, returning false if it was not in the vector, true otherwise.
 * @tparam T    The type of the item
 * @param list  The vector
 * @param item  The item to remove
 * @return      True if item was in list and got removed, false otherwise.
 */
template<typename T>
bool Remove(std::vector<std::shared_ptr<T>> *list, const std::shared_ptr<T> &item) {
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
std::vector<T *> ToRawPointers(const std::vector<std::shared_ptr<T>> &list) {
  std::vector<T *> result;
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
std::vector<T *> ToRawPointers(const std::vector<std::unique_ptr<T>> &list) {
  std::vector<T *> result;
  for (auto &value : list) {
    result.push_back(value.get());
  }
  return result;
}

/**
 * @brief Cast a vector of pointers to some other type.
 * @tparam T  The type of the objects being pointed to.
 * @param vec The vector of pointers.
 * @return    A list of raw pointers.
 */
template<typename T, typename U>
std::vector<T *> As(const std::vector<U *> &vec) {
  std::vector<T *> result;
  for (auto &value : vec) {
    result.push_back(dynamic_cast<T *>(value));
  }
  return result;
}

/// @brief Return a copy of a vector without any duplicates.
template<typename T>
std::vector<T> Unique(const std::vector<T> &vec) {
  auto result = vec;
  auto last = std::unique(result.begin(), result.end());
  result.erase(last, result.end());
  return vec;
}

/// @brief Filter duplicate entries from a vector.
template<typename T>
void FilterDuplicates(std::vector<T> *vec) {
  auto last = std::unique(vec->begin(), vec->end());
  vec->erase(last, vec->end());
}

/**
 * @brief Return a human-readable string from a type.
 * @tparam T  The type.
 * @return    The human-readable string.
 */
template<typename T>
std::string ToString() {
  return "UNKOWN TYPE";
}

/// @brief Create a directory.
void CreateDir(const std::string &dir_name);

/// @brief Check if file exists.
bool FileExists(const std::string &name);

}  // namespace cerata
