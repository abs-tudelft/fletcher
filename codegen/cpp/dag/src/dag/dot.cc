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

#include "dag/dot.h"

#include <sstream>
#include <string>
#include <regex>

namespace dag {

static std::string tab(int level) {
  return std::string(level * 2, ' ');
}

std::string replace(const std::string &str, const std::string &regex, const std::string &replace) {
  return std::regex_replace(str, std::regex(regex), replace);
}

inline std::string Sanitize(std::string str) {
  str = replace(str, R"(\\)", R"(&#92;)");
  str = replace(str, R"(\.)", R"(&diams;)");
  str = replace(str, R"(->)", R"(&rarr;)");
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
  for (auto &ch : result) {
    ch += 17;
  }
  return "C" + result;
}

std::string Name(const Graph &g) {
  std::stringstream str;
  str << reinterpret_cast<uint64_t>(&g);
  auto result = str.str();
  for (auto &c : result) {
    c += 17;
  }
  return "G" + result;
}

std::string Label(const Type &t, bool simple) {
  if (simple) {
    return t.name();
  } else {
    std::stringstream str;
    switch (t.id) {
      case TypeID::PRIM: str << Sanitize(t.name());
        break;
      case TypeID::LIST: {
        const auto &l = t.As<List>();
        if (l.canonical_name() == l.name()) {
          str << R"(<TABLE border="0" cellspacing="0" cellborder="0">)";
          str << R"(<TR><TD>)" << "list" << R"(</TD>)";
          str << R"(<TD>)" << Label(*l.item->type, simple) << R"(</TD></TR>)";
          str << R"(</TABLE>)";
        } else {
          str << l.name();
        }
        break;
      }
      case TypeID::STRUCT: {
        const auto &s = t.As<Struct>();
        if (s.canonical_name() == s.name()) {
          str << R"(<TABLE border="0" cellspacing="0" cellborder="0">)";
          for (const auto &f : s.fields) {
            str << R"(<TR><TD>)" << Sanitize(f->name) << R"(</TD>)";
            str << R"(<TD>)" << Label(*f->type, simple) << R"(</TD></TR>)";
          }
          str << R"(</TABLE>)";
        } else {
          str << s.name();
        }
        break;
      }
    }
    return str.str();
  }
}

std::string Label(const Vertex &v, bool simple) {
  if (!simple) {
    std::stringstream str;
    str << R"(<TABLE border="0" cellspacing="0" cellborder="0">)";
    str << R"(<TR><TD align="center"><B>)" << Sanitize(v.name) << R"(</B></TD></TR>)";
    str << R"(<TR><TD align="center">)" << Label(*v.type, simple) << R"(</TD></TR>)";
    str << R"(</TABLE>)";
    return str.str();
  } else {
    return Sanitize(v.name + ":" + v.type->name());
  }
}

struct MetaParamEvaluatingVisitor {
  std::string operator()(const std::string &fixed) { return fixed; }
  std::string operator()(const ProfileParamFunc &prof) { return "f(p)"; }
};

std::string Label(const Constant &c, bool simple) {
  auto name = Sanitize(c.name);
  auto val = Sanitize(visit(MetaParamEvaluatingVisitor(), c.value));
  if (simple) {
    return name + "=" + val;
  } else {
    std::stringstream str;
    str << R"(<TABLE border="0" cellspacing="0" cellborder="0">)";
    str << R"(<TR><TD align="center" cellpadding="0"><B>)" << name << R"(</B></TD></TR>)";
    str << R"(<TR><TD align="center" cellpadding="0">)" << val << R"(</TD></TR>)";
    str << R"(</TABLE>)";
    return str.str();
  }
}

std::string Label(const Edge &e) {
  return "";
}

std::string Label(const Graph &g) {
  return Sanitize(g.name);
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
  return R"(shape=box, style="rounded, filled", color="gray90", width=0, height=0, margin=0.05)";
}

std::string Style(const Edge &e) {
  std::stringstream result;
  switch (e.src_->type->id) {
    case TypeID::PRIM: result << R"(color="#c0a140", penwidth=1,)";
      break;
    case TypeID::LIST:result << R"(color="#7fc040", penwidth=3,)";
      break;
    case TypeID::STRUCT:result << R"(color="#40c091", penwidth=7,)";
      break;
  }
  // result << R"(tailport="s", headport="n")";
  return result.str();
}

static std::string TransformClusterStyle(int l = 0) {
  std::stringstream str;
  str << tab(l) << R"(label="";)" << std::endl;
  str << tab(l) << R"(style = invis;)" << std::endl;
  return str.str();
}

std::string Style(const Graph &g, int l) {
  std::stringstream str;
  if (l <= 1) {
    str << tab(l) << R"(nodesep=0;)" << std::endl;
    // str << tab(l) << R"(splines=compound;)" << std::endl;
    // str << tab(l) << R"(rankdir=TB;)" << std::endl;
    str << tab(l) << R"(ranksep=0.5;)" << std::endl;
    str << tab(l) << R"(margin="2, 2";)" << std::endl;
    str << tab(l) << R"(graph [fontname=")" << DOT_FONT << R"("];)" << std::endl;
    str << tab(l) << R"(node [fontname=")" << DOT_FONT << R"("];)" << std::endl;
    str << tab(l) << R"(edge [fontname=")" << DOT_FONT << R"("];)" << std::endl;
  } else {
    if (g.reads_memory || g.writes_memory) {
      str << tab(l) << R"(style = rounded;)" << std::endl;
      str << tab(l) << R"(color = "gray60";)" << std::endl;
      str << tab(l) << R"(bgcolor = "gray90";)" << std::endl;
      str << tab(l) << R"(node [shape=box, style="rounded, filled"])" << std::endl;
    } else {
      str << tab(l) << R"(style = rounded;)" << std::endl;
      str << tab(l) << R"(node [shape=box, style="rounded, filled"])" << std::endl;
    }
  }
  return str.str();
}

static std::string ConstsStyle(int l = 0) {
  std::stringstream str;
  str << tab(l) << R"(label="";)" << std::endl;
  str << tab(l) << R"(style = invis;)" << std::endl;
  return str.str();
}

static std::string InputsStyle(int l = 0) {
  std::stringstream str;
  str << tab(l) << R"(label="";)" << std::endl;
  str << tab(l) << R"(style = invis;)" << std::endl;
  return str.str();
}

static std::string OutputsStyle(int l = 0) {
  std::stringstream str;
  str << tab(l) << R"(label="";)" << std::endl;
  str << tab(l) << R"(style = invis;)" << std::endl;
  return str.str();
}

std::string AsDotGraph(const Graph &g, bool simple, int l) {
  std::stringstream str;
  // Header
  if (l == 0) {
    str << "digraph {\n";
  } else {
    str << tab(l) << "subgraph cluster_GRAPH" + Name(g) + "{\n";
  }
  str << tab(l + 1) << "label=\"" + Label(g) + "\"\n";
  str << Style(g, l + 1);

  // Constant nodes.
  if (!g.constants.empty()) {
    str << tab(l + 1) << "subgraph cluster_CONSTANTS_" << Name(g) << " {\n";
    str << tab(l + 1) << ConstsStyle(l + 1);
    for (const auto &c : g.constants) {
      str << tab(l + 1) << Name(*c) << " [label=<" + Label(*c, simple) + ">, " << Style(*c) + "];\n";
    }
    str << tab(l + 1) << "}\n";
  }

  // Input nodes.
  if (!g.inputs.empty()) {
    str << tab(l + 1) << "subgraph cluster_INPUTS_" << Name(g) << " {\n";
    str << InputsStyle(l + 2);
    for (const auto &i : g.inputs) {
      str << tab(l + 1) << Name(*i) << " [label=<" + Label(*i, simple) + ">, " << Style(*i) + "];\n";
    }
    str << tab(l + 1) << "}\n";
  }

  // Children
  for (const auto &child : g.children) {
    str << AsDotGraph(*child, simple, l + 1);
  }

  // Output nodes.
  if (!g.outputs.empty()) {
    str << tab(l + 1) << "subgraph cluster_OUTPUTS_" << Name(g) << " {\n";
    str << OutputsStyle(l + 2);
    for (const auto &o : g.outputs) {
      str << tab(l + 1) << Name(*o) << " [label=<" + Label(*o, simple) + ">, " << Style(*o) + "];\n";
    }
    str << tab(l + 1) << "}\n";
  }

  // Edges.
  for (const auto &e : g.edges) {
    str << tab(l + 1) << Name(*e->src_) << " -> " << Name(*e->dst_)
        << " [" << Style(*e) << "];\n";
  }

  str << tab(l) << "}" << std::endl;

  return str.str();
}

}  // namespace dag
