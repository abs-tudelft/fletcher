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

#include <optional>
#include <utility>
#include <memory>
#include <deque>
#include <vector>
#include <string>
#include <sstream>

#include "./utils.h"

namespace fletchgen {

class Type;
class Record;
class Stream;

/**
 * @brief A flattened type.
 */
struct FlatType {
  FlatType() = default;
  FlatType(std::shared_ptr<Type> t, std::deque<std::string> prefix, std::string name, int level);
  int nesting_level = 0;
  std::deque<std::string> name_parts;
  std::shared_ptr<Type> type;
  std::string name(std::string root = "", std::string sep = ":") const;
  bool operator<(FlatType &a) {
    return nesting_level < a.nesting_level;
  }
};
// Flattening functions for nested types:

/// @brief Flatten a Record.
void FlattenRecord(std::deque<FlatType> *list,
                   const std::shared_ptr<Record> &record,
                   const std::optional<FlatType> &parent);

/// @brief Flatten a Stream.
void FlattenStream(std::deque<FlatType> *list,
                   const std::shared_ptr<Stream> &stream,
                   const std::optional<FlatType> &parent);

/// @brief Flatten any Type.
void Flatten(std::deque<FlatType> *list,
             const std::shared_ptr<Type> &type,
             const std::optional<FlatType> &parent,
             std::string name);

/// @brief Flatten and return a list of FlatTypes.
std::deque<FlatType> Flatten(const std::shared_ptr<Type> &type);

/// @brief Return true if some Type is contained in a list of FlatTypes, false otherwise.
bool contains(const std::deque<FlatType> &flat_types_list, const std::shared_ptr<Type> &type);

/// @brief Return the index of some Type in a list of FlatTypes.
size_t index_of(const std::deque<FlatType> &flat_types_list, const std::shared_ptr<Type> &type);

/**
 * @brief Sort a list of flattened types by nesting level
 * @param list
 */
void Sort(std::deque<FlatType> *list);

/// @brief Convert a list of FlatTypes to a human-readable string.
std::string ToString(std::deque<FlatType> flat_type_list);

/**
 * @brief Compare if two types are weakly-equal, that is if their flattened Type ID list has the same levels and ids.
 * @param a The first type.
 * @param b The second type.
 * @return True if flattened Type ID list is the same, false otherwise.
 */
bool WeaklyEqual(const std::shared_ptr<Type> &a, const std::shared_ptr<Type> &b);

/**
 * @brief A structure to dynamically define type conversions on flattened types.
 */
class TypeConverter {
 public:
  TypeConverter() = default;
  TypeConverter(std::shared_ptr<Type> from, std::shared_ptr<Type> to);

  /* TODO(johanpel): This function with type parameters cannot work because types can occur multiple times in a
   * flattened type. It would, however be nice if there is a more syntactically pleasing way to produce the mapping. */
  // FlatTypeConverter &operator()(const std::shared_ptr<Type> &from, const std::shared_ptr<Type> &to);

  /// @brief Map source FlatType at index "from" to destination FlatType at index "to".
  TypeConverter &operator()(size_t from, size_t to);
  std::vector<std::optional<size_t>> conversion_map();
  std::deque<FlatType> flat_from();
  std::deque<FlatType> flat_to();
  bool CanConvert(std::shared_ptr<Type> from, std::shared_ptr<Type> to) const;
  std::string ToString() const;

 private:
  std::shared_ptr<Type> from_;
  std::shared_ptr<Type> to_;
  std::deque<FlatType> flat_from_;
  std::deque<FlatType> flat_to_;
  std::vector<std::optional<size_t>> conversion_map_;
};

}  // namespace fletchgen
