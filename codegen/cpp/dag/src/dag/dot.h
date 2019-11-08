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

#include "dag/dag.h"

namespace dag {

constexpr char DOT_FONT[] = "Bitstream Charter";

std::string Name(const Vertex &v);
std::string Name(const Edge &e);
std::string Name(const Graph &t);

std::string Label(const Constant &c, bool simple);
std::string Label(const Vertex &v, bool simple);
std::string Label(const Type &t, bool simple);
std::string Label(const Edge &e);
std::string Label(const Graph &g);

std::string Style(const Vertex &v);
std::string Style(const Edge &e);
std::string Style(const Graph &g, int l);

std::string AsDotGraph(const Graph &g, bool simple, int l = 0);

}  // namespace dag
