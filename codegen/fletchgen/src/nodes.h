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

#include <utility>
#include <optional>
#include <string>
#include <memory>
#include <deque>

#include "./types.h"

namespace fletchgen {

// Forward declarations.
struct Edge;
struct Graph;

/**
 * @brief A node.
 */
class Node : public Named, public std::enable_shared_from_this<Node> {
 public:
  /// @brief Node type IDs with different properties.
  enum ID {
    LITERAL,         ///< No-input     AND multi-output node with storage type and storage value.
    EXPRESSION,      ///< No-input     AND multi-output node that forms a binary tree with operations and nodes.
    SIGNAL,          ///< Single-input AND multi-output node.
    PORT,            ///< Single-input AND multi-output node with direction.
    PARAMETER,       ///< Single-input AND multi-output node with default value.
    ARRAY_SIGNAL,    ///< Multi-input  XOR multi-output node with count node.
    ARRAY_PORT,      ///< Multi-input  XOR multi-output node with count node and direction.
  };

  /// @brief Node constructor.
  Node(std::string name, ID id, std::shared_ptr<Type> type);

  /// @brief Get a copy of this Node.
  virtual std::shared_ptr<Node> Copy() const;

  /// @brief Return the node Type
  inline std::shared_ptr<Type> type() const { return type_; }
  /// @brief Set the node Type
  inline void SetType(const std::shared_ptr<Type> &type) { type_ = type; }
  /// @brief Return the node type ID
  inline ID id() const { return id_; }
  /// @brief Return whether this node is of a specific node type id.
  bool Is(ID node_id) const { return id_ == node_id; }
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
  /// @brief Return true if this is some type of ARRAY node, false otherwise.
  bool IsArray() const { return (id_ == ARRAY_PORT) || (id_ == ARRAY_SIGNAL); }
  /// @brief Return true if this is an ARRAY_PORT node, false otherwise.
  bool IsArrayPort() const { return id_ == ARRAY_PORT; }
  /// @brief Return true if this is an ARRAY_SIGNAL node, false otherwise.
  bool IsArraySignal() const { return id_ == ARRAY_SIGNAL; }

  /// @brief Get the input edges of this Node.
  virtual std::deque<std::shared_ptr<Edge>> inputs() const { return {}; }
  /// @brief Get the output edges of this Node.
  virtual std::deque<std::shared_ptr<Edge>> outputs() const { return {}; }
  /// @brief Add an input to this node.
  virtual void AddInput(const std::shared_ptr<Edge>& input) {}
  /// @brief Add an output to this node.
  virtual void AddOutput(const std::shared_ptr<Edge>& output) {}
  /// @brief Remove an edge of this node.
  virtual void RemoveEdge(const std::shared_ptr<Edge>& edge) {}

  /// @brief Set this node's parent
  void SetParent(const Graph *parent);
  inline std::optional<const Graph *> parent() { return parent_; }

  /// @brief Return a human-readable string
  virtual std::string ToString();

 protected:
  /// @brief Node type ID.
  ID id_;
  /// @brief The Type of this Node.
  std::shared_ptr<Type> type_;
  /// @brief An optional parent Graph to which this Node belongs. Initially no value.
  std::optional<const Graph *> parent_ = {};
};

struct MultiOutputsNode : public Node {
  /// @brief The outgoing Edges that sink this Node.
  std::deque<std::shared_ptr<Edge>> outputs_;

  MultiOutputsNode(std::string name, Node::ID id, std::shared_ptr<Type> type) : Node(std::move(name),
                                                                                     id,
                                                                                     std::move(type)) {}

  /// @brief Return the incoming edges (in this case just the single input edge).
  std::deque<std::shared_ptr<Edge>> inputs() const override { return {}; }
  /// @brief The outgoing Edges that sink this Node.
  inline std::deque<std::shared_ptr<Edge>> outputs() const override { return outputs_; }

  /// @brief Add an output edge to this node.
  void AddOutput(const std::shared_ptr<Edge>& edge) override;
  /// @brief Remove an edge from this node.
  void RemoveEdge(const std::shared_ptr<Edge>& edge) override;
  /// @brief Return output edge i of this node.
  inline std::shared_ptr<Edge> output(size_t i) const { return outputs_[i]; }
  /// @brief Return the number of edges of this node.
  inline size_t num_outputs() const { return outputs_.size(); }
};

struct NormalNode : public MultiOutputsNode {
  /// @brief The incoming Edge that sources this Node.
  std::shared_ptr<Edge> input_;

  NormalNode(std::string name, Node::ID id, std::shared_ptr<Type> type) : MultiOutputsNode(std::move(name),
                                                                                           id,
                                                                                           std::move(type)) {}

  /// @brief Return the incoming edges (in this case just the single input edge).
  std::deque<std::shared_ptr<Edge>> inputs() const override { return {input_}; }

  /// @brief Return the single incoming edge.
  std::optional<std::shared_ptr<Edge>> input();

  /// @brief Set the input edge of this node.
  void AddInput(const std::shared_ptr<Edge>& edge) override;
};

/**
 * @brief A Literal Node
 *
 * A literal node can be used to store some literal value. A literal node can, for example, be used for Vector Type
 * widths or it can be connected to a Parameter Node, to give the Parameter its value.
 */
struct Literal : public MultiOutputsNode {
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
      : MultiOutputsNode(std::move(name), Node::LITERAL, type),
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
  static std::shared_ptr<Literal> Make(int value);
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

  /// @brief A literal node has no inputs. This function returns an empty list.
  inline std::deque<std::shared_ptr<Edge>> inputs() const override { return {}; }
  /// @brief Get the output edges of this Node.
  inline std::deque<std::shared_ptr<Edge>> outputs() const override { return outputs_; }

  /// @brief Convert the Literal value to a human-readable string.
  std::string ToString() override;
};

/**
 * @brief A node representing a binary tree of other nodes
 */
struct Expression : public MultiOutputsNode {
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
  static std::shared_ptr<Node> Minimize(const std::shared_ptr<Node> &node);

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
 * @brief A Signal Node.
 *
 * A Signal Node can have a single input and multiple outputs.
 */
struct Signal : public NormalNode {
  /// @brief Signal constructor.
  Signal(std::string name, std::shared_ptr<Type> type);
  /// @brief Create a new Signal and return a smart pointer to it.
  static std::shared_ptr<Signal> Make(std::string name, const std::shared_ptr<Type> &type);
  /// @brief Create a new Signal and return a smart pointer to it. The Signal name is derived from the Type name.
  static std::shared_ptr<Signal> Make(const std::shared_ptr<Type> &type);
};

/**
 * @brief A Parameter node.
 *
 * Can be used to define implementation-specific characteristics of a Graph, or can be connected to e.g. Vector widths.
 */
struct Parameter : public NormalNode {
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
struct Port : public NormalNode {
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

/**
 * @brief A node where either inputs or outputs are concatenated.
 *
 * The flattened type of all connected nodes must be strongly equal, i.e. the widths of the flattened subtypes are all
 * the same.
 *
 * Example: If there is a connection from node "a" to both node "b" and "c", then "b" and "c" are said to be
 *          concatenated on the output of node "a".
 *
 * The number of edges that is concatenated onto an ArrayNode is stored as a pointer to a Node size_.
 * If size_ is an integer literal, it will automatically be incremented when nodes are added.
 * Otherwise, if the Node is a Parameter node being sourced by an integer literal, it can also be automatically be
 * incremented.
 *
 * Here, a, b and c must all have exactly the same flattened type list.
 */
struct ArrayNode : public Node {
  /// @brief Which side is concatenated.
  enum ConcatSide {
    OUT,
    IN
  } concat_side;
  /// @brief A node representing the number of concatenated edges.
  std::shared_ptr<Node> size_;
  /// @brief The concatenated side.
  std::shared_ptr<Edge> concat_;
  /// @brief The arrayed side.
  std::deque<std::shared_ptr<Edge>> arrayed_;
  /// @brief Concatenate a node onto this node and return an edge;
  std::shared_ptr<Edge> Concatenate(std::shared_ptr<Node> n);

  /// @brief Increment the size of the ArrayNode.
  void increment();
  void decrement();
};

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

/**
 * @brief Cast a Node to some (typically) less generic Node type T.
 * @tparam T    The new Node type.
 * @param obj   The Node to cast.
 * @return      Optionally, the Node casted to T, if successful.
 */
template<typename T>
std::optional<T *> Cast(Node *obj) {
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
std::shared_ptr<Literal> intl() {
  static std::shared_ptr<Literal> result = std::make_shared<Literal>("int" + std::to_string(V), integer(), V);
  return result;
}

/**
 * @brief Create a string literal.
 * @param str   The string value.
 * @return      A smart pointer to a literal node representing the string.
 */
std::shared_ptr<Literal> strl(std::string str);

/// @brief Return a literal node representing a Boolean true.
std::shared_ptr<Literal> bool_true();

/// @brief Return a literal node representing a Boolean false.
std::shared_ptr<Literal> bool_false();

}  // namespace fletchgen
