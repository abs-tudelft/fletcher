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
#include <string>
#include <memory>
#include <deque>

#include "./types.h"

namespace fletchgen {

// Forward Declr.
struct Edge;
struct Graph;

/**
 * @brief A node.
 */
class Node : public Named, public std::enable_shared_from_this<Node> {
 public:
  /// @brief Node type IDs.
  enum ID {
    PORT,
    SIGNAL,
    PARAMETER,
    LITERAL,
    EXPRESSION
  };

  /// @brief Node constructor.
  Node(std::string name, ID id, std::shared_ptr<Type> type);
  virtual ~Node() = default;

  /// @brief Get a copy of this Node
  virtual std::shared_ptr<Node> Copy() const;
  /// @brief Return the node Type
  std::shared_ptr<Type> type() const { return type_; }

  /// @brief Add an edge to this node as an input.
  void AddInput(std::shared_ptr<Edge> edge);
  /// @brief Add an edge to this node as an output.
  void AddOutput(std::shared_ptr<Edge> edge);
  /// @brief Remove an edge from this node.
  Node &RemoveEdge(const std::shared_ptr<Edge> &edge);
  /// @brief Return the number of edges of this node, both in and out.
  inline size_t num_edges() const { return ins_.size() + outs_.size(); }
  /// @brief Return the number of in edges of this node.
  inline size_t num_ins() const { return ins_.size(); }
  /// @brief Return the number of out edges of this node.
  inline size_t num_outs() const { return outs_.size(); }
  /// @brief Return all edges of this node, both in and out.
  std::deque<std::shared_ptr<Edge>> edges() const;
  /// @brief Return incoming Edge i.
  inline std::shared_ptr<Edge> in(size_t i) const { return ins_[i]; }
  /// @brief Return outgoing Edge i.
  inline std::shared_ptr<Edge> out(size_t i) const { return outs_[i]; }
  /// @brief Return all incoming edges.
  inline std::deque<std::shared_ptr<Edge>> ins() const { return ins_; }
  /// @brief Return all outgoing edges.
  inline std::deque<std::shared_ptr<Edge>> outs() const { return outs_; }

  /// @brief Return the node type ID
  inline ID id() const { return id_; }
  /// @brief Return whether this node is of a specific node type id.
  bool Is(ID tid) const { return id_ == tid; }
  /// @brief Return true if this is a PORT node, false otherwise.
  bool IsPort() const { return id_ == PORT; }
  /// @brief Return true if this is a SIGNAL node, false otherwise.
  bool IsSignal() const { return id_ == SIGNAL; }
  /// @brief Return true if this is a PARAMETER node, false otherwise.
  bool IsParameter() const { return id_ == PARAMETER; }
  /// @brief Return true if this is a LITERAL node, false otherwise.
  bool IsLiteral() const { return id_ == LITERAL; }
  /// @brief Return true if this is an EXPRESSION node, false otherwise.
  bool IsExpression() const { return id_ == EXPRESSION; }

  /// @brief Set this node's parent
  void SetParent(const Graph *parent);
  inline std::optional<const Graph *> parent() { return parent_; }

  /// @brief Return a human-readable string
  virtual std::string ToString();

 private:
  /// @brief Node type ID.
  ID id_;
  /// @brief The Type of this Node.
  std::shared_ptr<Type> type_;
  /// @brief All incoming Edges of this Node.
  std::deque<std::shared_ptr<Edge>> ins_;
  /// @brief All outgoing Edges of this Node.
  std::deque<std::shared_ptr<Edge>> outs_;
  /// @brief An optional parent Graph to which this Node belongs. Initially none.
  std::optional<const Graph *> parent_ = {};
};

/**
 * @brief A Signal Node
 *
 * Can be used to build up some Graph structure, e.g. to connect two Instance ports.
 *
 * TODO(johanpel): do we -really- need this or should an emitter figure this out? Smells like VHDL.
 */
struct Signal : public Node {
  /// @brief Signal constructor.
  Signal(std::string name, std::shared_ptr<Type> type);

  /// @brief Create a new Signal and return a smart pointer to it.
  static std::shared_ptr<Signal> Make(std::string name, const std::shared_ptr<Type> &type);

  /// @brief Create a new Signal and return a smart pointer to it. The Signal name is derived from the Type name.
  static std::shared_ptr<Signal> Make(const std::shared_ptr<Type> &type);
};

/**
 * @brief A Literal Node
 *
 * A literal node can be used to store some literal value. A literal node can, for example, be used for Vector Type
 * widths or it can be connected to a Parameter Node, to give the Parameter its value.
 */
struct Literal : public Node {
  /// @brief The actual storage type of the value.
  enum StorageType { INT, STRING, BOOL } storage_type_;

  /// @brief The string storage.
  std::string str_val_ = "";

  /// @brief The integer storage.
  int int_val_ = 0;

  /// @brief The boolean storage.
  bool bool_val_ = false;

  /// @brief Literal constructor.
  Literal(std::string name,
          const std::shared_ptr<Type> &type,
          StorageType st,
          std::string str_val,
          int int_val,
          bool bool_val)
      : Node(std::move(name), Node::LITERAL, type),
        storage_type_(st),
        str_val_(std::move(str_val)),
        int_val_(int_val) {}

  /// @brief Construct a new Literal with a string storage type.
  Literal(std::string name, const std::shared_ptr<Type> &type, std::string value);

  /// @brief Construct a new Literal with an integer storage type.
  Literal(std::string name, const std::shared_ptr<Type> &type, int value);

  /// @brief Construct a new Literal with a boolean storage type.
  Literal(std::string name, const std::shared_ptr<Type> &type, bool value);

  /// @brief Get a smart pointer to a new Literal with string storage, where the Literal name will be the string.
  static std::shared_ptr<Literal> Make(const std::shared_ptr<Type> &type, std::string value);

  /// @brief Get a smart pointer to a new Literal with a string storage type.
  static std::shared_ptr<Literal> Make(std::string name, const std::shared_ptr<Type> &type, std::string value);

  /// @brief Get a smart pointer to a new Literal with an integer storage type.
  static std::shared_ptr<Literal> Make(std::string name, const std::shared_ptr<Type> &type, int value);

  /// @brief Get a smart pointer to a new Literal with a boolean storage type.
  static std::shared_ptr<Literal> Make(std::string name, const std::shared_ptr<Type> &type, bool value);

  /// @brief Create a copy of this Literal.
  std::shared_ptr<Node> Copy() const override;

  /// @brief Convert the Literal value to a human-readable string.
  std::string ToString() override;
};

/**
 * @brief A Parameter node.
 *
 * Can be used to define implementation-specific characteristics of a Graph, or can be connected to e.g. Vector widths.
 */
struct Parameter : public Node {
  /// @brief An optional default value.
  std::optional<std::shared_ptr<Literal>> default_value;

  /// @brief Construct a new Parameter, optionally defining a default value Literal.
  Parameter(std::string name,
            const std::shared_ptr<Type> &type,
            std::optional<std::shared_ptr<Literal>> default_value = {});

  /// @brief Get a smart pointer to a new Parameter, optionally defining a default value Literal.
  static std::shared_ptr<Parameter> Make(std::string name,
                                         std::shared_ptr<Type> type,
                                         std::optional<std::shared_ptr<Literal>> default_value = {});

  /// @brief Create a copy of this Parameter.
  std::shared_ptr<Node> Copy() const override;
};

/**
 * @brief A Port node.
 *
 * Can be used to define Graph terminators. Port nodes enforce proper directionality of edges.
 */
struct Port : public Node {
  /// @brief Port direction.
  enum Dir { IN, OUT } dir;

  /// @brief Construct a new Port.
  Port(std::string name, std::shared_ptr<Type> type, Dir dir);

  /// @brief Get a smart pointer to a new Port.
  static std::shared_ptr<Port> Make(std::string name, std::shared_ptr<Type> type, Dir dir = Dir::IN);;

  /// @brief Get a smart pointer to a new Port. The Port name is derived from the Type name.
  static std::shared_ptr<Port> Make(std::shared_ptr<Type> type, Dir dir = Dir::IN);;

  /// @brief Create a copy of this Port.
  std::shared_ptr<Node> Copy() const override;

  /// @brief Return true if this Port is an input, false otherwise.
  bool IsInput() { return dir == IN; }

  /// @brief Return true if this Port is an output, false otherwise.
  bool IsOutput() { return dir == OUT; }
};

/*
 * @brief A node representing a binary tree of other nodes
 */
struct Expression : Node {
  enum Operation { ADD, SUB, MUL, DIV } operation;
  std::shared_ptr<Node> lhs;
  std::shared_ptr<Node> rhs;
  /**
   * @brief Construct a new expression
   * @param op  The operator between two operands
   * @param lhs The left operand
   * @param rhs The right operand
   */
  Expression(Operation op, const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs);

  /// @brief Short-hand to create a smart pointer to an expression.
  static std::shared_ptr<Expression> Make(Operation op,
                                          const std::shared_ptr<Node> &lhs,
                                          const std::shared_ptr<Node> &rhs);

  /// @brief Minimize a node, if it is an expression
  static std::shared_ptr<Node> Minimize(const std::shared_ptr<Node>& node);

  /// @brief Copy this expression.
  std::shared_ptr<Node> Copy() const override;

  /// @brief Minimize the expression and convert it to a human-readable string.
  std::string ToString() override;
};

std::string ToString(Expression::Operation operation);
std::shared_ptr<Expression> operator+(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs);
std::shared_ptr<Expression> operator-(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs);
std::shared_ptr<Expression> operator*(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs);
std::shared_ptr<Expression> operator/(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs);

/**
 * @brief Cast a Node to some (typically) less generic Node type T.
 * @tparam T    The new Node type.
 * @param obj   The Node to cast.
 * @return      Optionally, the Node casted to T, if successful.
 */
template<typename T>
std::optional<std::shared_ptr<T>> Cast(const std::shared_ptr<Node> &obj) {
  auto result = std::dynamic_pointer_cast<T>(obj);
  if (result != nullptr) {
    return result;
  } else {
    return {};
  }
}

/// @brief Convert a Node ID to a human-readable string.
std::string ToString(Node::ID id);

// Some often used literals for convenience:
/**
 * @brief Create an integer Literal.
 * @tparam V    The integer value.
 * @return      A smart pointer to a literal node representing the value.
 */
template<int V>
std::shared_ptr<Literal> litint() {
  static std::shared_ptr<Literal> result = std::make_shared<Literal>("lit_" + std::to_string(V), integer(), V);
  return result;
}

/**
 * @brief Create a string literal.
 * @param str   The string value.
 * @return      A smart pointer to a literal node representing the string.
 */
std::shared_ptr<Literal> litstr(std::string str);

/// @brief Return a literal node representing a Boolean true.
std::shared_ptr<Literal> bool_true();

/// @brief Return a literal node representing a Boolean false.
std::shared_ptr<Literal> bool_false();

/// @brief Return a human-readable string with information about the node.
std::string ToString(const std::shared_ptr<Node> &node);

}  // namespace fletchgen
