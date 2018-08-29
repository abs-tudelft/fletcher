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
#include <stdexcept>
#include <memory>
#include <utility>
#include <vector>
#include <unordered_map>
#include <map>
#include <cmath>

/**
 * This file contains classes to help generate VHDL in general.
 */

namespace vhdl {

// Forward declarations:
class Range;
class Architecture;
class Instantiation;
class Connection;
class Component;

constexpr int COL_ALN = 48;  ///< Typographical column alignment for assignments, etc...
constexpr int COL_MAX = 79;  ///< Typographical max width of VHDL output. Not strictly enforced. Used for seperators.
constexpr char INT_SIG[] = "s"; ///< Prefix for internal architecture signals

/// @brief Return the log2 of \p num, rounding the result up.
int log2ceil(int num);

/// @brief Checks if a string is a valid VHDL identifier.
bool isIdentifier(const std::string &str);

/// @brief Attempts to convert a string into a valid VHDL identifier.
std::string makeIdentifier(const std::string &str);

/**
 * @brief Returns a seperator to be used in VHDL comments.
 * @param tabs The indentation level.
 * @return A VHDL comment with lots of '-'s.
 */
std::string seperator(int tabs = 0);

/**
 * @brief Returns a string with 2*i spaces.
 * @param i Half the number of spaces to return.
 * @return A string with 2*i spaces.
 */
std::string t(int i);

/**
 * @brief Returns a string with a prefix and suffix and a separator at a specific position.
 * Inserts whitespace to align the seperator.
 * @param prefix The prefix string.
 * @param separator The seperator string.
 * @param suffix The suffix string.
 * @param pos The position at which to place seperator.
 * @return Concatenation of prefix, seperator and suffix with seperator at pos, if possible.
 */
std::string alignStat(const std::string &prefix,
                      const std::string &separator,
                      const std::string &suffix,
                      uint32_t pos);

/**
 * @brief Create and return a VHDL identifier concatenated form multiple strings.
 * The seperator "_" is used in between every part of the identifier.
 * @param strings The strings to concatenate
 * @return The VHDL identifier.
 */
std::string nameFrom(std::vector<std::string> strings);

/// @brief A direction for ports.
typedef enum {
  IN, ///< Input
  OUT ///< Output
} Dir;

/**
 * @brief Reverses direction.
 * @param dir The direction to reverse.
 * @return The reverse Direction of dir.
 */
Dir rev(Dir dir);

/**
 * @brief Converts Direction to string.
 * @param dir The direction to convert.
 * @return The string "in" or "out".
 */
std::string dir2str(Dir dir);

/**
 * @brief A comment to be placed near some other VHDL statement.
 */
class Comment {
 public:

  /// @brief Comment location.
  enum Place {
    BEFORE, ///< Place the comment before the declaration/statement/expression/etc...
    AFTER ///< Place the comment after the declaration/statement/expression/etc...
  };

  Comment() = default;

  virtual ~Comment() = default;;

  /**
   * @brief Construct a comment.
   * @param comment The comment.
   * @param place Where to place the comment. Default=BEFORE.
   */
  explicit Comment(std::string comment, Comment::Place place = BEFORE) :
      comment_(std::move(comment)),
      place_(place) {}

  /// @brief Return the comment string.
  std::string comment() { return comment_; }

  /**
   * @brief Change the comment string to \p comment.
   * @param comment The new comment.
   */
  void setComment(std::string comment) { comment_ = std::move(comment); }

  /// @brief Return the placement of this comment.
  Place place() { return place_; }

  /**
   * @brief Change the position of this comment to /p place.
   * @param place The new place.
   */
  void place(Place place) { place_ = place; }

  /// @brief Return the VHDL string of this comment.
  virtual std::string toVHDL() { return comment_; }

 private:
  std::string comment_ = "";
  Place place_ = BEFORE;
};

/**
 * @brief Allows declarations, assignments, etc.. to be groupable in the VHDL output.
 */
class Groupable {
 public:
  Groupable() = default;;

  explicit Groupable(int group) { group_ = group; }

  static bool compare(Groupable *a, Groupable *b) {
    return a->group() < b->group();
  }

  static bool compare_sp(const std::shared_ptr<Groupable> &a, const std::shared_ptr<Groupable> &b) {
    return a->group() < b->group();
  }

  /**
 * @brief Set a grouping for this port.
 * Ports in the same group will be placed together in the declaration.
 * @param group The group.
 */
  void setGroup(int group) { group_ = group; }

  /**
   * @return The port group.
   */
  int group() { return group_; }

 private:
  int group_ = -1;
};

/**
 * @brief Holds either numerical or generic port widths.
 */
class Value {
 public:
  /// @brief Construct a value zero.
  Value();

  /**
   * @brief Construct a value from a string.
   * @param str The name of the generic.
   */
  explicit Value(int val) : str_(""), val_(val) {}

  /**
   * @brief Construct the value from an integer.
   * @param val The number of bits for this port.
   */
  explicit Value(std::string str) : str_(std::move(str)), val_(0) {}

  /// @brief Compare two values.
  bool operator==(Value value);

  /// @brief Check if two values are unequal.
  bool operator!=(Value value);

  /// @brief Multiply two values.
  Value operator*(Value value);

  /// @brief Multiply a value by an integer.
  Value operator*(int mult);

  /// @brief Add two values.
  Value operator+(Value value);

  /// @brief Add a value and an integer.
  Value operator+(int value);

  /// @brief Increment value by an integer \p x.
  Value operator+=(int x);

  /// @brief Subtract two values.
  Value operator-(Value value);

  /// @brief Return a range from this value down to 0.
  Range asRangeDowntoZero();

  /// @brief Return the VHDL string of
  std::string toString();

 private:
  std::string str_;
  int val_;
};

/**
 * @brief A range for vector ports.
 */
class Range {
 public:
  /// @brief Type of this range.
  enum Type {
    SINGLE, ///< A single index on a bus. Implies signal_name(X).
    DOWNTO, ///< A "high bit index" downto "low bit index" range. Implies signal_name(X downto Y).
    TO,     ///< A "low bit index" to "high bit index" range. Implies signal_name(Y to X).
    ALL     ///< All elements of whatever this range applies to. Implies signal_name (without any range or index).
  };

  /// @brief Construct a range of type "ALL".
  Range() = default;

  /**
   * @brief Construct a VHDL range of high downto low.
   * @param high The high bit index.
   * @param low The low bit index.
   * @param type The type, default type is Range::Type::DOWNTO, which means a "high downto low" range.
   */
  Range(Value high, Value low, Type type = DOWNTO) :
      high_(std::move(high)),
      low_(std::move(low)),
      type_(type) {}

  std::string toVHDL();

  std::string toString();

  Value high() { return high_; }

  Value low() { return low_; }

  Range::Type type() { return type_; }

 private:
  Value high_;
  Value low_;
  Range::Type type_ = Range::Type::ALL;
};

/**
 * @brief A hardware signal
 */
class Signal : public Comment, public Groupable {
 public:
  /**
   * @brief Construct a vector signal with width \p width.
   * @param name The signal name.
   * @param width The signal width.
   */
  Signal(std::string name, Value width, bool is_vector = true);

  /**
   * @brief Construct a (non-vector) signal.
   * @param name The signal name.
   */
  explicit Signal(std::string name);

  /**
   * @brief Generate the VHDL declaration of this port.
   * @return A string containing the declaration of this port.
   */
  std::string toVHDL() override;

  std::string name() { return name_; }

  Value width() { return width_; }

  virtual std::string toString() { return "[SIGNAL: " + name_ + " | width: " + width_.toString() + "]"; }

  /**
   * @return Whether this signal is a vector or not.
   */
  bool isVector();

 protected:
  std::string name_;
  Value width_;
  bool vec_;
};

/**
 * @brief A hardware port.
 */
class Port : public Signal {
 public:
  /**
   * @brief Construct a bus port.
   * @param name The name of the port.
   * @param dir The direction of the port.
   * @param w The width of the port.
   */
  Port(std::string name, Dir dir, Value width) : Signal(std::move(name), std::move(width)), dir_(dir) {}

  /**
   * @brief Construct signal port.
   * @param name The name of the port.
   * @param dir The direction of the port.
   */
  Port(std::string name, Dir dir) : Signal(std::move(name)), dir_(dir) {}

  /// @brief Return the direction of this port.
  Dir dir();

  /// @brief Invert the direction of this port.
  Port *invert() {
    dir_ = rev(dir_);
    return this;
  }

  /**
   * @brief Generate the VHDL declaration of this port.
   * @return A string containing the declaration of this port.
   */
  std::string toVHDL() override;

  /// @brief Return a human readable string of this Port.
  std::string toString() override;

 private:
  Dir dir_;
};

/**
 * @brief A connection between two signals.
 */
class Connection : public Comment, public Groupable {
 public:
  Connection(Signal *destination, Range dest_range, Signal *source, Range source_range, bool invert = false);

  std::string toVHDL() override;

  Signal *source() { return source_; }

  Signal *dest() { return dest_; }

  Range source_range() { return source_range_; }

  Range dest_range() { return dest_range_; }

  bool inverted() { return invert_; }

  /**
   * Comparison function for sorting of Connections
   */
  static struct sortFun_ { bool operator()(std::shared_ptr<Connection> &a, std::shared_ptr<Connection> &b); } sortFun;

 private:
  Signal *source_;
  Signal *dest_{};
  Range source_range_ = Range(Value(), Value());
  Range dest_range_ = Range(Value(), Value());
  bool invert_ = false;
};

/**
 * @brief A generic.
 */
class Generic : public Comment, public Groupable {
 public:
  Generic(std::string name, std::string type, const Value &value, int group = 0) : Groupable(group) {
    name_ = std::move(name);
    type_ = std::move(type);
    value_ = value;
  }

  std::string name() { return name_; }

  std::string toVHDL() override;

  ///@brief Generate a VHDL declaration of this generic, but omit the default value.
  std::string toVHDLNoDefault();

  std::string toString() { return "[GENERIC: " + name() + "]"; }

 private:
  std::string name_;
  std::string type_;
  Value value_;
};

/**
 * @brief An entity.
 */
class Entity : public Comment {
 public:
  explicit Entity(std::string name);

  ///@brief Return a VHDL string of the entity declaration.
  std::string toVHDL() override;

  /**
   * @brief Add a port to this entity.
   * @param port The port to add.
   * @param group Optionally a new group id for the port.
   */
  void addPort(const std::shared_ptr<Port> &port, int group);

  void addPort(const std::shared_ptr<Port> &port);

  ///@brief Add a generic to this entity.
  void addGeneric(const std::shared_ptr<Generic> &generic);

  /// @brief Return the ports of this entity.
  std::vector<Port *> ports();

  /// @brief Return the generics of this entity.
  std::vector<Generic *> generics();

  std::string name() { return name_; }

  /**
   * @brief Obtain the a pointer to a port object with some name on this entity.
   * @param name The name of the port.
   * @return The port if exists, nullptr otherwise.
   */
  Port *getPortByName(const std::string &name);

  /**
   * @brief Obtain the a pointer to a generic object with some name on this entity.
   * @param name The name of the generic.
   * @return The generic if exists, nullptr otherwise.
   */
  Generic *getGenericByName(const std::string &name);

  /**
   * @brief Check if a generic with name exists on this entity.
   * @param name The name
   * @return True if exists, false otherwise.
   */
  bool hasGenericWithName(const std::string &name);

  /**
   * @brief Check if a generic exists in this entity
   * @param generic The generic
   * @return True if exists, false otherwise.
   */
  bool hasGeneric(Generic *generic);

  /**
   * @brief Check if a port with name exists on this entity.
   * @param name The name
   * @return True if exists, false otherwise.
   */
  bool hasPortWithName(const std::string &name);

  /**
   * @brief Check if a port exists in this entity.
   * @param port The port.
   * @return True if exists, false otherwise.
   */
  bool hasPort(Port *port);

  std::string toString() { return "[ENTITY: " + name_ + "]"; }

 private:
  std::string name_;
  std::vector<std::shared_ptr<Port>> ports_;
  std::vector<std::shared_ptr<Generic>> generics_;
};

/**
 * A statement
 */
class Statement : public Comment {
 public:
  Statement(const std::string &prefix,
            const std::string &sep,
            const std::string &suffix)
      : str_(alignStat(prefix, sep, suffix, COL_ALN)) {};

  std::string toVHDL() { return str_; }
 private:
  std::string str_;
};

/**
 * @brief An architecture.
 */
class Architecture : public Comment {
 public:
  /**
   * @brief Architecture constructor.
   * @param name The name/
   */
  Architecture(std::string name, std::shared_ptr<Entity> entity);

  /// @brief Add a concurrent statement to the architecture.
  Statement* addStatement(std::shared_ptr<Statement> statement);

  /**
   * @brief Add a signal to the architecture.
   * @param signal The signal.
   * @return A pointer to the signal.
   */
  Signal *addSignal(std::shared_ptr<Signal> signal, int group = 0);

  /**
   * @brief Create a signal on the architecture that is derived from a port.
   * New signal has same name and width. Optionally a prefix for the signal name can be provided.
   * @param port The port to derive the signal from
   * @param prefix A prefix for the signal names.
   * @return A pointer to the signal that was created.
   */
  Signal *addSignalFromPort(Port *port, std::string prefix = "", int group = 0);

  /**
   * @brief Add signals to the architecture, derived from the ports of a specific entity.
   * Optionally provide a prefix for the signal names.
   * @param entity The entity to derive the signals from.
   * @param prefix A prefix for the signal names.
   */
  void addSignalsFromEntityPorts(Entity *entity, std::string prefix = "", int group = 0);

  /**
   * @brief Remove a signal from the architecture.
   * @param signal The signal to remove.
   */
  void removeSignal(Signal *signal);

  /**
   * @brief Remove a signal with some name from the architecture.
   * @param signal The signal name to find and remove.
   */
  void removeSignal(std::string signal);

  /**
   * @brief Add a connection to the architecture.
   * @param connection The connection.
   */
  void addConnection(const std::shared_ptr<Connection> &connection);

  /**
   * @brief Add a component instantiation to the architecture.
   * @param inst The instantiation to add.
   */
  void addInstantiation(const std::shared_ptr<Instantiation> &inst);

  /**
   * @brief Add a component declaration to the architecture.
   * @param comp
   */
  void addComponent(const std::shared_ptr<Component> &comp);

  /**
   * @brief Return a signal by name, if it exists.
   * Otherwise this function returns a nullptr.
   * @param name The name of the signal to return.
   * @return A pointer to the signal, nullptr otherwise.
   */
  Signal *getSignal(const std::string &name);

  /**
   * @brief Generate VHDL code for this architecture.
   * @return A string containing the VHDL code.
   */
  std::string toVHDL() override;

  std::string name() { return name_; }

  std::vector<std::shared_ptr<Signal>> signals() { return signals_; }

  std::vector<std::shared_ptr<Connection>> connections() { return connections_; }

  std::vector<std::shared_ptr<Instantiation>> instances() { return instances_; }

  std::string toString() { return "[ARCHITECTURE: " + name_ + " of " + entity_->toString() + "]"; }

 private:
  std::string name_;
  std::shared_ptr<Entity> entity_;
  std::vector<std::shared_ptr<Signal>> signals_;
  std::vector<std::shared_ptr<Connection>> connections_;
  std::vector<std::shared_ptr<Instantiation>> instances_;
  std::vector<std::shared_ptr<Component>> comp_decls_;
  std::vector<std::shared_ptr<Statement>> statements_;
};

/**
 * @brief A component.
 */
class Component : public Comment {
 public:
  ~Component() override = default;

  explicit Component(std::string name) :
      entity_(std::make_shared<Entity>(name)),
      architecture_(std::make_shared<Architecture>("Implementation", entity_)) {}

  std::shared_ptr<Entity> entity() { return entity_; }

  std::shared_ptr<Architecture> architecture() { return architecture_; }

  virtual std::string toString() { return "[COMPONENT: " + entity()->name() + "]"; }

  /**
   * @brief Return the component declaration in VHDL.
   */
  std::string toVHDL() override;

 protected:
  std::shared_ptr<Entity> entity_;
  std::shared_ptr<Architecture> architecture_;
};

/**
 * @brief A component instantiation.
 */
class Instantiation : public Comment {
 public:
  /**
   * @brief Construct an Instantiation and related component.
   * New component, entity and architecture will be constructed.
   * @param name The name of this Instantiation.
   * @param comp_name The name of the Component and Entity to construct.
   */
  Instantiation(std::string name, std::string comp_name) :
      name_(std::move(name)),
      comp_(std::make_shared<Component>(comp_name)) {}

  /**
   * @brief Construct an Instantiation of a Component
   * @param name The name of this Instantiation.
   * @param component The Component to instantiate.
   */
  Instantiation(std::string name, std::shared_ptr<Component> component) :
      name_(std::move(name)),
      comp_(std::move(component)) {}

  explicit Instantiation(std::shared_ptr<Component> component);

  /**
   * @brief Map a \p port to a \p destination signal.
   * @param port The port to map, if it exists.
   * @param destination The string to map it to.
   * @param range The reange of the destination signal
   */
  void mapPort(Port *port, Signal *destination, Range dest_range = Range());

  /**
   * @brief Map a \p generic to a \p value.
   * @param generic The generic to map, if it exists
   * @param value The value to map to the generic.
   */
  void mapGeneric(Generic *generic, Value value);

  std::string toVHDL() override;

  virtual std::string toString() { return "[INSTANTIATION: " + comp_->entity()->name() + "]"; }

  std::shared_ptr<Component> component() { return comp_; }

  virtual std::string name() { return name_; };

 protected:
  std::string name_; ///< Name of this instantiation.
  std::shared_ptr<Component> comp_; ///< The component being instantiated.
  std::map<Generic *, Value> generic_map_; ///< Generic mapping.
  std::map<Port *, std::pair<Signal *, Range>> port_map_; ///< Port mapping.

};

}//namespace fletchgen