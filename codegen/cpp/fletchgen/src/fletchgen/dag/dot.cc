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

#include "fletchgen/dag/dot.h"

#include <sstream>
#include <string>
#include <regex>

namespace fletchgen::dag {

std::string replace(const std::string &str, const std::string &regex, const std::string &replace) {
  return std::regex_replace(str, std::regex(regex), replace);
}

inline std::string Sanitize(std::string str) {
  str = replace(str, R"(\\)", R"(&#92;)");
  str = replace(str, R"(\<)", R"(&lt;)");
  str = replace(str, R"(\>)", R"(&gt;)");
  return str;
}

std::string Name(const Vertex &v) {
  std::stringstream str;
  str << reinterpret_cast<uint64_t>(&v);
  auto result = str.str();
  for (auto &c : result) {
    c += 17;
  }
  return "V" + result;
}

std::string Name(const Constant &c) {
  std::stringstream str;
  str << reinterpret_cast<uint64_t>(&c);
  auto result = str.str();
  for (auto &c : result) {
    c += 17;
  }
  return "C" + result;
}

std::string Name(const Transform &t) {
  std::stringstream str;
  str << reinterpret_cast<uint64_t>(&t);
  auto result = str.str();
  for (auto &c : result) {
    c += 17;
  }
  return "T" + result;
}

std::string Label(const Type &t) {
  std::stringstream str;
  switch (t.id) {
    case TypeID::PRIM: str << Sanitize(t.name);
      break;
    case TypeID::LIST: str << Sanitize(t.name);
      break;
    case TypeID::STRUCT: {
      str << R"(<TABLE border="0" cellspacing="0" cellborder="0">)";
      for (const auto &f : t.As<Struct>()->fields) {
        str << R"(<TR><TD>)" << Sanitize(f->name) << R"(</TD>)";
        str << R"(<TD>)" << Label(*f->type) << R"(</TD></TR>)";
      }
      str << R"(</TABLE>)";
      break;
    }
  }
  return str.str();
}

std::string Label(const Vertex &v) {
  std::stringstream str;
  str << R"(<TABLE border="0" cellspacing="0" cellborder="0">)";
  str << R"(<TR><TD align="center"><B>)" << Sanitize(v.name) << R"(</B></TD></TR>)";
  str << R"(<TR><TD align="center">)" << Label(*v.type) << R"(</TD></TR>)";
  str << R"(</TABLE>)";
  return str.str();
}

struct MetaParamEvaluatingVisitor {
  std::string operator()(const std::string &fixed) { return fixed; }
  std::string operator()(const ProfileParamFunc &prof) { return "f(p)"; }
};

std::string Label(const Constant &c) {
  std::stringstream str;
  auto name = Sanitize(c.name);
  auto val = Sanitize(visit(MetaParamEvaluatingVisitor(), c.value));
  str << R"(<TABLE border="0" cellspacing="0" cellborder="0">)";
  str << R"(<TR><TD align="center" cellpadding="0"><B>)" << name << R"(</B></TD></TR>)";
  str << R"(<TR><TD align="center" cellpadding="0">)" << val << R"(</TD></TR>)";
  str << R"(</TABLE>)";
  return str.str();
}

std::string Label(const Edge &e) {
  return "";
}

std::string Label(const Transform &t) {
  return Sanitize(t.name);
}

std::string Style(const TypeRef &t) {
  switch (t->id) {
    case TypeID::PRIM:return R"(fillcolor="#ffe081", color="#c0a140")";
    case TypeID::LIST:return R"(fillcolor="#bfff81", color="#7fc040")";
    case TypeID::STRUCT:return R"(fillcolor="#81ffd1", color="#40c091")";
  }
}

std::string Style(const Vertex &v) {
  if (v.IsInput()) {
    return Style(v.type);
  } else {
    return Style(v.type);
  }
}

std::string Style(const Constant &c) {
  return "shape=box, style=\"rounded, filled\", color=\"gray90\", width=0, height=0, margin=0.05";
}

std::string Style(const Edge &e) {
  std::stringstream result;
  switch (e.src_->type->id) {
    case TypeID::PRIM: result << R"(fillcolor="#ffe081", color="#c0a140")";
      break;
    case TypeID::LIST:result << R"(fillcolor="#bfff81", color="#7fc040")";
      break;
    case TypeID::STRUCT:result << R"(fillcolor="#81ffd1", color="#40c091")";
      break;
  }
  result << " penwidth=3";
  return result.str();
}

std::string Style(const Transform &t) {
  if (t.name == "Source") {
    return "style = rounded; "
           "color = \"gray60\"; "
           "bgcolor = \"gray90\"; "
           "node [shape=box, style=\"rounded, filled\"]\n";
  } else if (t.name == "Sink") {
    return "style = rounded; "
           "color = \"gray60\"; "
           "bgcolor = \"gray90\"; "
           "node [shape=box, style=\"rounded, filled\"]\n";
  } else {
    return "style = rounded; "
           "bgcolor = \"white\"; "
           "node [shape=box, style=\"rounded, filled\"]\n";
  }
}

std::string AsDotGraph(const Graph &g) {
  std::stringstream str;
  // Header
  str << "digraph {\n";
  // Transformations.
  for (const auto &t : g.transformations) {
    str << "  subgraph cluster_" << Name(*t) << " {\n";
    str << "    labeljust=l\n";
    str << "    label = \"" << Label(*t) << "\";\n";
    str << "    " << Style(*t) << "\n";

    // Constant nodes.
    if (!t->constants.empty()) {
      str << "    subgraph cluster_C" << Name(*t) << " {\n";
      str << "      label = \"\";\n";
      str << "      style = invis;\n";
      for (const auto &c : t->constants) {
        str << "    " << Name(*c) << " [label=<" + Label(*c) + ">, " << Style(*c) + "];\n";
      }
      str << "    }\n";
    }

    // Input nodes.
    if (!t->inputs.empty()) {
      str << "    subgraph cluster_I" << Name(*t) << " {\n";
      str << "      label=\"\";\n";
      str << "      style = invis;\n";
      for (const auto &i : t->inputs) {
        str << "    " << Name(*i) << " [label=<" + Label(*i) + ">, " << Style(*i) + "];\n";
      }
      str << "    }\n";
    }

    // Output nodes.
    if (!t->outputs.empty()) {
      str << "    subgraph cluster_O" << Name(*t) << " {\n";
      str << "      label=\"\";\n";
      str << "      style = invis;\n";
      for (const auto &o : t->outputs) {
        str << "    " << Name(*o) << " [label=<" + Label(*o) + ">, " << Style(*o) + "];\n";
      }
      str << "    }\n";
    }
    str << "  }\n";
  }
  // Edges.
  for (const auto &e : g.edges) {
    str << "  " << Name(*e->src_) << " -> " << Name(*e->dst_)
        << " [" << Style(*e) << "];\n";
  }
  str << "}";

  return str.str();
}

}  // namespace fletchgen::dag
