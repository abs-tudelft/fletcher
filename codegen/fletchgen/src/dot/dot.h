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

#include "../components.h"

namespace fletchgen {
namespace dot {

std::deque<std::shared_ptr<Edge>> GetAllEdges(const std::shared_ptr<Component> &comp);

struct PortStyle {
  std::string base;
  std::string stream;
  std::string clock;
  std::string reset;
  std::string vector;
  std::string bit;
};

struct ParamStyle {
  std::string base;
};

struct LitStyle {
  std::string base;
};

struct SigStyle {
  std::string base;
};

struct Style {
  std::string port_to_sig;
  std::string sig_to_port;
  std::string stream;
  std::string edge;
  std::string litedge;
  PortStyle port;
  LitStyle lit;
  ParamStyle param;
  SigStyle sig;

  static Style basic();
};

struct Grapher {
  Style style;
  std::deque<std::shared_ptr<Edge>> generated;

  Grapher() : style(Style::basic()){}
  explicit Grapher(Style style) : style(std::move(style)) {}

  std::string GenEdges(const std::shared_ptr<Component> &comp, int level = 0);
  std::string GenNodes(const std::shared_ptr<Component> &comp, int level = 0);
  std::string GenComponent(const std::shared_ptr<Component> &comp, int level = 0);

  std::string GenFile(const std::shared_ptr<Component> &comp, std::string path);
};

}  // namespace dot
}  // namespace fletchgen
