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

#include <utility>
#include <iostream>
#include <algorithm>
#include <regex>

#include "../logging.h"
#include "vhdl.h"

namespace vhdl {

constexpr char IDENTIFIER_REGEX[] = "(?!.*__)[a-zA-Z][\\w]*[^_]";

int log2ceil(int num) {
  auto l2 = std::log2<int>(num);
  auto cl2 = std::ceil(l2);
  return static_cast<int>(cl2);
}

bool isIdentifier(const std::string &basic_string) {
  std::regex id_regex(IDENTIFIER_REGEX);
  return std::regex_match(basic_string, id_regex);
}

std::string makeIdentifier(const std::string &str) {
  if (!isIdentifier(str)) {
    std::string ret = str;
    // TODO: add more
    std::replace(ret.begin(), ret.end(), ' ', '_');

    if (!isIdentifier(ret)) {
      throw std::runtime_error("Could not convert string \"" + str + "\" into valid VHDL identifier.");
    }
    return ret;
  } else {
    return str;
  }
}

std::string t(int i) {
  std::string ret(uint64_t(2 * i), ' ');
  return ret;
}

std::string seperator(int tabs) {
  return t(tabs) + std::string(static_cast<unsigned long>(COL_MAX - tabs * 2), '-') + "\n";
}

std::string alignStat(const std::string &prefix,
                      const std::string &separator,
                      const std::string &suffix,
                      uint32_t pos) {
  int len = (pos - 1) - (int) prefix.length();
  if (len < 0) len = 0;
  return prefix + std::string((uint64_t) len, ' ') + separator + suffix;
}

//TODO(johanpel): use va_arg ?
std::string nameFrom(std::vector<std::string> strings) {
  std::string ret;

  auto i = strings.begin();
  while (i != strings.end()) {
    if (i->empty()) {
      i = strings.erase(i);
    } else {
      ++i;
    }
  }

  for (const auto &str : strings) {
    if (!str.empty()) {
      if (str != strings.front()) {
        ret += "_";
      }
      ret += str;
    }
  }

  return ret;
}

Range Value::asRangeDowntoZero() {
  auto high = *this - Value(1);
  return Range(high, Value(0));
}

std::string Value::toString() {
  std::string ret = str_;
  if (val_ != 0) {
    if (!ret.empty()) {
      if (val_ > 0)
        ret += "+";
      if (val_ < 0)
        ret += "-";
    }
    ret += std::to_string(std::abs(val_));
  } else if (str_.empty()) {
    ret += "0";
  }
  return ret;
}

Value Value::operator+(Value value) {
  Value ret;
  ret.val_ = val_;
  ret.str_ = str_;

  ret.val_ = ret.val_ + value.val_;

  if (!value.str_.empty()) {
    if (!ret.str_.empty()) {
      //TODO: do something fancy here to make n*str -> (n+1)*str if the str is the same
      ret.str_ += "+";
    }
    ret.str_ += value.str_;
  }

  return ret;
}

Value Value::operator*(Value value) {
  Value ret;
  ret.str_ = val_ == 1 ? str_ : "";
  ret.val_ = val_ * value.val_;

  if (!str_.empty()) {
    if (!value.str_.empty()) {
      ret.str_ = str_ + "*" + value.str_;
    }
  }

  if (value.val_ > 1) {
    if (!str_.empty()) {
      if (!ret.str_.empty())
        ret.str_ += "+";
      ret.str_ += std::to_string(value.val_) + "*" + str_;
    }
  }

  if (val_ > 1) {
    if (!value.str_.empty()) {
      if (!ret.str_.empty())
        ret.str_ += "+";
      ret.str_ += std::to_string(val_) + "*" + value.str_;
    }
  }

  return ret;
}

Value Value::operator*(int mult) {
  Value ret;
  ret.val_ = val_;
  ret.str_ = str_;

  if (mult != 1) {
    return ret * Value(mult);
  } else {
    return ret;
  }
}

Value Value::operator+(int val) {
  Value ret;
  ret.val_ = val;
  ret.str_ = str_;

  if (val != 0) {
    return ret + Value(val);
  } else {
    return ret;
  }
}

Value Value::operator-(Value value) {
  Value ret;
  ret.val_ = val_;
  ret.str_ = str_;

  ret.val_ = ret.val_ - value.val_;

  if (!value.str_.empty()) {
    if (!ret.str_.empty())
      ret.str_ += "-";
    ret.str_ += value.str_;
  }
  return ret;
}

Value::Value() {
  str_ = "";
  val_ = 0;
}

bool Value::operator!=(Value value) {
  return !(*this == std::move(value));
}

bool Value::operator==(Value value) {
  if (this->str_ == value.str_) {
    if (this->val_ == value.val_) {
      return true;
    }
  }
  return false;
}

Value Value::operator+=(int x) {
  return *this + Value(x);
}

std::string Port::toVHDL() {
  if (vec_) {
    return comment() + alignStat(t(2) + name_,
                                 ": ",
                                 dir2str(dir_) + " std_logic_vector(" + width_.asRangeDowntoZero().toVHDL() + ")",
                                 COL_ALN);
  } else {
    return comment() + alignStat(t(2) + name_, ": ", dir2str(dir_) + " std_logic", COL_ALN);
  }
}

bool Signal::isVector() { return vec_; }

Dir Port::dir() { return dir_; }

std::string Port::toString() {
  return "[PORT: " + name_ + " | Dir: " + dir2str(dir_) + (isVector() ? " | width: " + width_.toString() + "]" : "]");
}

Dir rev(Dir dir) {
  if (dir == IN) {
    return Dir::OUT;
  } else
    return Dir::IN;
}

std::string dir2str(Dir dir) {
  if (dir == IN) {
    return "in";
  } else
    return "out";
}

std::string Signal::toVHDL() {
  if (vec_) {
    return comment() + alignStat(t(1) + "signal " + name_,
                                 ": ",
                                 "std_logic_vector(" + width_.asRangeDowntoZero().toVHDL() + ");",
                                 COL_ALN);
  } else {
    return comment() + alignStat(t(1) + "signal " + name_, ": ", "std_logic;", COL_ALN);
  }
}

Signal::Signal(std::string name, Value width, bool is_vector) : Groupable(),
                                                                name_(std::move(name)),
                                                                width_(std::move(width)),
                                                                vec_(is_vector) {
  if ((!vec_) && (width_ != Value(1))) {
    throw std::runtime_error("Signal is not-vector but has width other than 1.");
  }
  if (name_.empty()) {
    throw std::runtime_error("Signal name cannot be blank.");
  }
}

Signal::Signal(std::string name) : Signal(std::move(name), Value(1), false) {}

std::string Connection::toVHDL() {
  std::string source_string;

  // Apply inversion for string generation:
  auto source = invert_ ? dest_ : source_;
  auto source_range = invert_ ? dest_range_ : source_range_;
  auto dest = invert_ ? source_ : dest_;
  auto dest_range = invert_ ? source_range_ : dest_range_;

  source_string = source->name();

  if (source_range.type() != Range::Type::ALL)
    source_string += +"(" + source_range.toVHDL() + ")";

  auto sep_string = "<= ";

  auto dest_string = dest->name();

  if (dest_range.type() != Range::Type::ALL)
    dest_string += "(" + dest_range.toVHDL() + ")";

  return comment() + alignStat(t(1) + source_string, sep_string, dest_string + ";", COL_ALN);
}

Connection::Connection(Signal *destination, Range dest_range, Signal *source, Range source_range, bool invert)
    : Groupable(),
      source_(source),
      dest_(destination),
      source_range_(std::move(source_range)),
      dest_range_(std::move(dest_range)),
      invert_(invert) {
  if (source == nullptr) {
    throw std::runtime_error("DerivedFrom for connection is null pointer.");
  }
  if (destination == nullptr) {
    throw std::runtime_error("Destination for connection is null pointer.");
  }
}

std::string Generic::toVHDLNoDefault() {
  return comment() + alignStat(t(2) + name_, ": ", type_, COL_ALN);
}

std::string Generic::toVHDL() {
  return comment() + alignStat(t(2) + name_, ": ", type_ + " := " + value_.toString(), COL_ALN);
}

Entity *Entity::addGeneric(const std::shared_ptr<Generic> &generic) {
  if (!hasGenericWithName(generic->name())) {
    generics_.push_back(generic);
  } else {
    throw std::runtime_error("Generic " + generic->name() + " already exists on entity " + name_);
  }
  return this;
}

void Entity::addPort(const std::shared_ptr<Port> &port, int group) {
  LOGD("Adding port " + port->toString() + " to " + toString());
  if (!hasPortWithName(port->name())) {
    port->setGroup(group);
    ports_.push_back(port);
  } else {
    throw std::runtime_error("Port " + port->name() + " already exists on entity " + name_);
  }
}

void Entity::addPort(const std::shared_ptr<Port> &port) {
  addPort(port, port->group());
}

Port *Entity::getPortByName(const std::string &name) {
  for (auto const &port : ports_) {
    if (port->name() == name)
      return port.get();
  }
  return nullptr;
}

Generic *Entity::getGenericByName(const std::string &name) {
  for (auto const &generic : generics_) {
    if (generic->name() == name)
      return generic.get();
  }
  return nullptr;
}

std::string Entity::toVHDL() {
  std::string ret = comment();
  ret += "entity " + name_ + " is\n";

  // Generics:
  if (!generics_.empty()) {
    ret += "  generic(\n";
    // Sort generics by group id
    std::sort(generics_.begin(), generics_.end(), Groupable::compare_sp);
    int group = generics_.front()->group();

    for (auto const &gen : generics_) {
      if (gen->group() != group) {
        ret += seperator(2);
        group = gen->group();
      }
      ret += gen->toVHDLNoDefault();
      if (generics_.back() != gen) {
        ret += ";";
      }
      ret += "\n";
    }
    ret += "  );\n";
  }

  // Ports:
  if (!ports_.empty()) {
    ret += "  port(\n";

    // Sort ports by group id
    std::sort(ports_.begin(), ports_.end(), Groupable::compare_sp);

    // Get the first group id
    int group = ports_.front()->group();

    for (auto const &p : ports_) {
      if (p->group() != group) {
        ret += seperator(2);
        group = p->group();
      }
      ret += p->toVHDL();
      if (ports_.back() != p) {
        ret += ";";
      }
      ret += "\n";
    }
    ret += "  );\n";
  }
  ret += "end " + name_ + ";\n";

  return ret;
}

Entity::Entity(std::string name) {
  name_ = std::move(name);
}

bool Entity::hasGenericWithName(const std::string &name) {
  for (const auto &gen : generics_) {
    if (gen->name() == name) {
      return true;
    }
  }
  return false;
}

bool Entity::hasGeneric(Generic *generic) {
  for (const auto &gen : generics_) {
    if (gen.get() == generic) {
      return true;
    }
  }
  return false;
}

bool Entity::hasPortWithName(const std::string &name) {
  for (const auto &port : ports_) {
    if (port->name() == name) {
      return true;
    }
  }
  return false;
}

bool Entity::hasPort(Port *port) {
  for (const auto &p : ports_) {
    if (p.get() == port) {
      return true;
    }
  }
  return false;
}

std::vector<Port *> Entity::ports() {
  std::vector<Port *> ret;
  for (const auto &p: ports_) {
    ret.push_back(p.get());
  }
  return ret;
}

std::vector<Generic *> Entity::generics() {
  std::vector<Generic *> ret;
  for (const auto &g: generics_) {
    ret.push_back(g.get());
  }
  return ret;
}

Architecture::Architecture(std::string name, std::shared_ptr<Entity> entity) {
  name_ = std::move(name);
  entity_ = std::move(entity);
}

void Architecture::addComponent(const std::shared_ptr<Component> &comp) {
  LOGD("Declaring " + comp->toString() + " in " + toString());
  comp_decls_.push_back(comp);
}

void Architecture::addInstantiation(const std::shared_ptr<Instantiation> &inst) {
  LOGD("Instantiating " + inst->toString() + " in " + toString());
  // Check if instance already exists:
  for (const auto &i : instances_) {
    if (i->name() == inst->name()) {
      throw std::runtime_error("Signal with name " + inst->name() + " already exists on " + toString());
    }
  }
  instances_.push_back(inst);
}

Signal *Architecture::addSignal(const std::shared_ptr<Signal> &signal, int group) {
  LOGD("Declaring " + signal->toString() + " in " + toString());
  // Check if signal already exists:
  for (const auto &s : signals_) {
    if (s->name() == signal->name()) {
      throw std::runtime_error("Signal with name " + signal->name() + " already exists on " + toString());
    }
  }
  signals_.push_back(signal);
  signal->setGroup(group);
  return signal.get();
}

Signal *Architecture::addSignalFromPort(Port *port, std::string prefix, int group) {
  if (!port->isVector()) {
    return addSignal(std::make_shared<Signal>(prefix + "_" + port->name()), group);
  } else {
    return addSignal(std::make_shared<Signal>(prefix + "_" + port->name(), port->width()), group);
  }
}

void Architecture::addSignalsFromEntityPorts(Entity *entity, std::string prefix, int group) {
  // Create a signal on the top-level for each port.
  for (const auto &port : entity->ports()) {
    addSignalFromPort(port, prefix);
  }
}

Signal *Architecture::getSignal(const std::string &name) {
  for (auto const &signal : signals_) {
    if (signal->name() == name)
      return signal.get();
  }
  LOGD("Could not find signal with name " + name);
  return nullptr;
}

void Architecture::addConnection(const std::shared_ptr<Connection> &connection) {
  if (connection->inverted()) {
    LOGD("Connecting source " + connection->source()->toString() + " " + connection->source_range().toString() +
         " to sink " + connection->dest()->toString() + " " + connection->dest_range().toString());
  } else {
    LOGD("Connecting source " + connection->dest()->toString() + " " + connection->dest_range().toString() +
         " to sink " + connection->source()->toString() + " " + connection->source_range().toString());
  }

  connections_.push_back(connection);
}

std::string Architecture::toVHDL() {
  std::string ret = comment();

  ret += "architecture " + name_ + " of " + entity_->name() + " is\n";
  ret += "\n";

  int group = 0;

  /* Component declarations */
  if (!comp_decls_.empty()) {
    for (const auto &c: comp_decls_) {
      ret += seperator(1);
      ret += c->toVHDL();
    }
    ret += seperator(1);
    ret += "\n";
  }

  /* Signal declarations */
  if (!signals_.empty()) {
    std::sort(signals_.begin(), signals_.end(), Groupable::compare_sp);

    group = signals_.front()->group();

    for (const auto &s : signals_) {
      if (s->group() != group) {
        ret += seperator(1);
        group = s->group();
      }
      ret += s->toVHDL() + "\n";
    }
  }

  ret += "begin\n";

  /* Component instantiations */
  for (const auto &inst : instances_) {
    ret += inst->toVHDL() + "\n";
  }

  ret += "\n";

  /* Connections */
  // Sort connections by name first
  std::sort(connections_.begin(), connections_.end(), Connection::sortFun);
  // Then by group
  std::sort(connections_.begin(), connections_.end(), Groupable::compare_sp);

  group = connections_.front()->group();

  for (const auto &con :connections_) {
    if (con->group() != group) {
      ret += seperator(1);
      group = con->group();
    }
    ret += con->toVHDL() + "\n";
  }

  ret += seperator(1);

  /* Statements */
  for (const auto &stat : statements_) {
    ret += stat->toVHDL() + "\n";
  }

  ret += "\nend architecture;\n";

  return ret;
}

void Architecture::removeSignal(Signal *signal) {
  if (signal != nullptr) {
    for (auto s = signals_.begin(); s != signals_.end(); s++) {
      if (s->get() == signal) {
        signals_.erase(s);
        return;
      }
    }
    LOGE("Cannot remove " + signal->name() + " from " + this->toString() + " because it does not exist.");
  }
  throw std::runtime_error("Attempt to remove a nullptr signal.");
}

void Architecture::removeSignal(std::string signal) {
  auto sig = getSignal(signal);
  if (sig != nullptr) {
    removeSignal(sig);
  } else {
    LOGE("Cannot remove " + signal + " from " + this->toString() + " because it does not exist.");
  }
}

Statement *Architecture::addStatement(std::shared_ptr<Statement> statement) {
  statements_.push_back(statement);
  return statement.get();
}

Instantiation::Instantiation(std::shared_ptr<Component> component) :
    name_(nameFrom({component->entity()->name(), "_inst"})),
    comp_(std::move(component)) {}

std::string Instantiation::toVHDL() {
  std::string ret = comment();

  ret += t(1) + name_ + ": " + comp_->entity()->name() + "\n";

  if (!generic_map_.empty()) {
    ret += t(2) + "generic map (\n";

    auto generics = component()->entity()->generics();
    auto n = false;
    // For all generics:
    for (const auto &g: generics) {
      // Check if the generic is mapped:
      auto val = generic_map_.find(g);
      if (val != generic_map_.end()) {
        if (n) {
          ret += ",\n";
        } else {
          n = true;
        }
        ret += alignStat(t(3) + g->name(), "=> ", val->second.toString(), COL_ALN);

      }
    }
    ret += "\n" + t(2) + ")\n";
  }

  ret += "    port map (\n";

  if (!port_map_.empty()) {
    auto ports = component()->entity()->ports();
    auto n = false;
    // For all ports:
    for (const auto &p : ports) {
      // Check if the port is mapped:
      auto port = port_map_.find(p);
      if (port != port_map_.end()) {
        if (n) {
          ret += ",\n";
        } else {
          n = true;
        }
        auto name_str = port->second.first->name();
        auto range_str = port->second.second.toVHDL();
        std::string dest = name_str;
        if ((port->second.second.type() != Range::ALL) && (port->second.first->isVector())) {
          dest += "(" + range_str + ")";
        }
        ret += alignStat(t(3) + port->first->name(), "=> ", dest, COL_ALN);
      }
    }
  }

  ret += "\n" + t(2) + ");\n";

  return ret;
}

void Instantiation::mapPort(Port *port, Signal *destination, Range dest_range) {
  if (port == nullptr) {
    throw std::runtime_error("Port cannot be nullptr.");
  }
  if (destination == nullptr) {
    throw std::runtime_error("Destination cannot be nullptr.");
  }

  LOGD("Mapping port " + port->toString() + " to " + destination->toString());

  if (comp_->entity()->hasPort(port)) {
    port_map_.insert(std::pair<Port *, std::pair<Signal *, Range>>{port, {destination, dest_range}});
  } else {
    throw std::runtime_error("Port " + port->toString() + " does not exist on " + comp_->entity()->toString());
  }
}

void Instantiation::mapGeneric(Generic *generic, Value value) {
  if (generic == nullptr) {
    throw std::runtime_error("Generic cannot be nullptr.");
  }

  LOGD("Mapping generic " + generic->toString() + " to value: " + value.toString());

  if (comp_->entity()->hasGeneric(generic)) {
    generic_map_.insert(std::pair<Generic *, Value>{generic, value});
  } else {
    throw std::runtime_error("Generic " + generic->toString() + " does not exist on " + comp_->entity()->toString());
  }
}

bool Connection::sortFun_::operator()(const std::shared_ptr<Connection> &a, const std::shared_ptr<Connection> &b) {
  return a->source_->name() < b->source_->name();
}

std::string Range::toString() {
  if (type_ == ALL) {
    return "(ALL)";
  } else if (type_ == SINGLE) {
    return "(" + high_.toString() + ")";
  } else {
    if (type_ == DOWNTO) {
      return "(" + high_.toString() + " downto " + low_.toString() + ")";
    } else {
      return "(" + low_.toString() + " to " + high_.toString() + ")";
    }
  }
}

std::string Range::toVHDL() {
  if (type_ == ALL) {
    return "";
  } else if (type_ == SINGLE) {
    return high_.toString();
  } else {
    if (type_ == DOWNTO) {
      return high_.toString() + " downto " + low_.toString();
    } else {
      return low_.toString() + " to " + high_.toString();
    }
  }
}

std::string Component::toVHDL() {
  std::string ret = comment();
  ret += t(1) + "component " + entity()->name() + " is\n";

  auto generics = entity()->generics();

  // Generics:
  if (!entity()->generics().empty()) {
    ret += t(1) + "  generic(\n";
    // Sort generics by group id
    std::sort(generics.begin(), generics.end(), Groupable::compare);
    int group = generics.front()->group();

    for (auto const &gen : generics) {
      if (gen->group() != group) {
        ret += seperator(3);
        group = gen->group();
      }
      ret += t(1) + gen->toVHDLNoDefault();
      if (generics.back() != gen) {
        ret += ";";
      }
      ret += "\n";
    }
    ret += t(1) + "  );\n";
  }

  auto ports = entity()->ports();

  // Ports:
  if (!ports.empty()) {
    ret += t(1) + "  port(\n";

    //TODO(johanpel): this sorting should be the other way around but there is something messy with the group ids
    // Sort ports by group id
    std::sort(ports.begin(), ports.end(), Groupable::compare);

    // Sort ports by name
    std::sort(ports.begin(), ports.end(), [](const Port* a, const Port* b) {
      return a->name() > b->name();
    });

    // Get the first group id
    int group = ports.front()->group();

    for (auto const &p : ports) {
      if (p->group() != group) {
        ret += seperator(3);
        group = p->group();
      }
      ret += t(1) + p->toVHDL();
      if (ports.back() != p) {
        ret += ";";
      }
      ret += "\n";
    }
    ret += t(1) + "  );\n";
  }
  ret += t(1) + "end component;\n";

  return ret;
}

}