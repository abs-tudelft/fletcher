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

#include <utility>
#include <optional>
#include <string>
#include <memory>
#include <vector>
#include <unordered_map>

#include "cerata/object.h"
#include "cerata/type.h"
#include "cerata/node.h"
#include "cerata/pool.h"

namespace cerata {

/**
 * @brief A node representing a binary tree of other nodes.
 */
class Expression : public MultiOutputNode {
 public:
  /// Binary expression operator enum class
  enum class Op { ADD, SUB, MUL, DIV };

  /// @brief Short-hand to create a smart pointer to an expression.
  static std::shared_ptr<Expression> Make(Op op, std::shared_ptr<Node> lhs, std::shared_ptr<Node> rhs);

  /// @brief Copy this expression.
  std::shared_ptr<Object> Copy() const override;

  /// @brief Copy this expression onto a graph and rebind anything in the expression tree.
  Node *CopyOnto(Graph *dst, const std::string &name, NodeMap *rebinding) const override;
  /// @brief Depth-first traverse the expression tree and add any nodes owned.
  void AppendReferences(std::vector<Object *> *out) const override;

  /// @brief Minimize the expression and convert it to a human-readable string.
  std::string ToString() const override;

  /// @brief Return the left-hand side node of the expression.
  Node *lhs() const { return lhs_.get(); }
  /// @brief Return the right-hand side node of the expression.
  Node *rhs() const { return rhs_.get(); }

 protected:
  /// @brief Minimize a node, if it is an expression, otherwise just returns a copy of the input.
  static std::shared_ptr<Node> Minimize(Node *node);
  /// @brief Merge expressions of integer literals into their resulting integer literal.
  static std::shared_ptr<Node> MergeIntLiterals(Expression *exp);
  /// @brief Eliminate nodes that have zero or one on either side for specific expressions.
  static std::shared_ptr<Node> EliminateZeroOne(Expression *exp);

  /**
  * @brief Construct a new expression
  * @param op  The operator between two operands
  * @param lhs The left operand
  * @param rhs The right operand
  */
  Expression(Op op, std::shared_ptr<Node> lhs, std::shared_ptr<Node> rhs);

  /// The binary operator of this expression.
  Op operation_;
  /// The left hand side node.
  std::shared_ptr<Node> lhs_;
  /// The right hand side node.
  std::shared_ptr<Node> rhs_;
};

/// @brief Human-readable expression operator.
std::string ToString(Expression::Op operation);

// Macros to generate expression generators
#ifndef EXPRESSION_OP_FACTORY
#define EXPRESSION_OP_FACTORY(SYMBOL, OPID)                                                    \
inline std::shared_ptr<Node> operator SYMBOL (const std::shared_ptr<Node>& lhs,                \
                                              const std::shared_ptr<Node>& rhs) {              \
  return Expression::Make(Expression::Op::OPID, lhs, rhs);                                     \
}                                                                                              \
                                                                                               \
inline std::shared_ptr<Node> operator SYMBOL (const std::shared_ptr<Node>& lhs,                \
                                              Node* rhs) {                                     \
  return Expression::Make(Expression::Op::OPID, lhs, rhs->shared_from_this());                 \
}                                                                                              \
                                                                                               \
inline std::shared_ptr<Node> operator SYMBOL (const std::shared_ptr<Node>& lhs, int64_t rhs) { \
  if (lhs->IsLiteral()) {                                                                      \
    auto li = std::dynamic_pointer_cast<Literal>(lhs);                                         \
    if (li->storage_type() == Literal::StorageType::INT) {                                     \
      return default_node_pool()->GetLiteral(li->IntValue() SYMBOL rhs);                       \
    }                                                                                          \
  }                                                                                            \
  return lhs SYMBOL intl(rhs);                                                                 \
}                                                                                              \
                                                                                               \
inline std::shared_ptr<Node> operator SYMBOL (Node& lhs, int64_t rhs) {                        \
  if (lhs.IsLiteral()) {                                                                       \
    auto& li = dynamic_cast<Literal&>(lhs);                                                    \
    if (li.storage_type() == Literal::StorageType::INT) {                                      \
      return default_node_pool()->GetLiteral(li.IntValue() SYMBOL rhs);                        \
    }                                                                                          \
  }                                                                                            \
  return lhs.shared_from_this() SYMBOL intl(rhs);                                              \
}
#endif

EXPRESSION_OP_FACTORY(+, ADD)
EXPRESSION_OP_FACTORY(-, SUB)
EXPRESSION_OP_FACTORY(*, MUL)
EXPRESSION_OP_FACTORY(/, DIV)

}  // namespace cerata
