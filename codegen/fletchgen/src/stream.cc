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

#include <sstream>
#include <iostream>
#include <utility>

#include "vhdl/vhdl.h"
#include "stream.h"
#include "column.h"

using std::shared_ptr;
using std::string;
using std::vector;
using std::move;
using std::make_shared;

namespace fletchgen {

Stream::Stream(string name, vector<shared_ptr<StreamPort>> ports) :
    name_(move(name)) {
  ports_.insert(ports_.begin(), ports.begin(), ports.end());
}

void Stream::addPort(const shared_ptr<StreamPort> &port) {
  ports_.push_back(port);
}

void Stream::addPort(vector<shared_ptr<StreamPort>> ports) {
  for (const auto &p : ports) {
    p->setParent(this);
    ports_.push_back(p);
  }
}

vector<shared_ptr<StreamPort>> Stream::ports() {
  vector<shared_ptr<StreamPort>> ret;
  for (const auto &p: ports_) {
    ret.push_back(p);
  }
  return ret;
}

Stream *Stream::invert() {
  for (const auto &p: ports_) {
    p->invert();
  }
  return this;
}

Stream *Stream::setGroup(int group) {
  for (const auto &p : ports_) {
    p->setGroup(group);
  }
  return this;
}

string StreamComponent::toString() {
  string ret = "[COMPONENT: " + entity()->name() + " | Streams: ";
  for (const auto &s: _streams) {
    ret += s->name() + ", ";
  }
  ret += "]";
  return ret;
}

void StreamComponent::addStreamPorts(int *group) {
  // For each stream, at the ports on the entity
  for (const auto &s: streams()) {
    for (const auto &p: s->ports()) {
      if (group != nullptr) {
        entity()->addPort(p, *group);
      } else {
        entity()->addPort(p);
      }
    }
    if (group != nullptr) {
      (*group)++;
    }
  }
}

}//namespace fletchgen