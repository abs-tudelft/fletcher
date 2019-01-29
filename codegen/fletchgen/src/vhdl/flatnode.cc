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

#include "./flatnode.h"

#include <memory>
#include <deque>
#include <tuple>
#include <sstream>
#include <iomanip>

#include "../nodes.h"

#include "./vhdl_types.h"

namespace fletchgen {
namespace vhdl {

std::string FlatNode::ToString() const {
  std::stringstream ret;
  ret << "FlatNode: " << node_->name() << std::endl;
  for (const auto &t : tuples_) {
    ret << "  " << std::setw(16) << std::get<0>(t).ToString()
        << " : " << std::get<1>(t)->name() << std::endl;
  }
  return ret.str();
}


FlatNode::FlatNode(std::shared_ptr<Node> node) : node_(std::move(node)) {
  // Obtain the top-level node name and create an identifier
  Identifier top;
  top.append(node_->name());
  // Flatten the node type
  Flatten(top, node_->type_);
}

void FlatNode::Flatten(const Identifier &prefix, const std::shared_ptr<Record> &record) {
  for (const auto &f : record->fields()) {
    Flatten(prefix + f->name(), f->type());
  }
}

void FlatNode::Flatten(const Identifier &prefix, const std::shared_ptr<Stream> &stream) {
  // Put valid and ready signal
  tuples_.emplace_back(prefix + "valid", valid());
  tuples_.emplace_back(prefix + "ready", ready());

  // Insert element type
  Flatten(prefix + stream->element_name(), stream->element_type());
}

void FlatNode::Flatten(const Identifier &prefix, const std::shared_ptr<Type> &type) {
  if (type->Is(Type::RECORD)) {
    Flatten(prefix, Cast<Record>(type));
  } else if (type->Is(Type::STREAM)) {
    Flatten(prefix, Cast<Stream>(type));
  } else {
    // Not nested types
    tuples_.emplace_back(prefix, type);
  }
}

std::deque<std::tuple<Identifier, std::shared_ptr<Type>>> FlatNode::tuples() {
  return tuples_;
}

size_t FlatNode::size() {
  return tuples_.size();
}

std::tuple<Identifier, std::shared_ptr<Type>> FlatNode::GetTuple(size_t i) {
  return tuples_[i];
}

}  // namespace vhdl
}  // namespace fletchgen
