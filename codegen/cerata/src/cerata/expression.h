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
  static std::shared_ptr<Expression> Make(Op op, std::shared_ptr<const Node> lhs, std::shared_ptr<const Node> rhs);

  /// @brief Add an input to this node.
  std::shared_ptr<Edge> AddSource(Node *source) override;

  /// @brief Copy this expression.
  std::shared_ptr<Object> Copy() const override;

  /// @brief Minimize the expression and convert it to a human-readable string.
  std::string ToString() const override;

  /// @brief Return the left-hand side node of the expression.
  const Node *lhs() const { return lhs_.get(); }
  /// @brief Return the right-hand side node of the expression.
  const Node *rhs() const { return rhs_.get(); }

  /// @brief Recursively list any nodes that this node owns.
  std::deque<const Node *> ownees() const override {
    std::deque<const Node *> result;
    result.push_back(lhs_.get());
    result.push_back(rhs_.get());
    auto lh_ownees = lhs_->ownees();
    auto rh_ownees = rhs_->ownees();
    result.insert(result.end(), lh_ownees.begin(), lh_ownees.end());
    result.insert(result.end(), rh_ownees.begin(), rh_ownees.end());
    return result;
  }

 protected:
  /// @brief Minimize a node, if it is an expression, otherwise just returns a copy of the input.
  static std::shared_ptr<const Node> Minimize(const Node *node);
  /// @brief Merge expressions of integer literals into their resulting integer literal.
  static std::shared_ptr<const Node> MergeIntLiterals(const Expression *exp);
  /// @brief Eliminate nodes that have zero or one on either side for specific expressions.
  static std::shared_ptr<const Node> EliminateZeroOne(const Expression *exp);

  /**
  * @brief Construct a new expression
  * @param op  The operator between two operands
  * @param lhs The left operand
  * @param rhs The right operand
  */
  Expression(Op op, std::shared_ptr<const Node> lhs, std::shared_ptr<const Node> rhs);

  /// The binary operator of this expression.
  Op operation_;
  /// The left hand side node.
  std::shared_ptr<const Node> lhs_;
  /// The right hand side node.
  std::shared_ptr<const Node> rhs_;
};

/// @brief Human-readable expression operator.
std::string ToString(Expression::Op operation);

// Macros to generate expression generators
#ifndef EXPRESSION_OP_FACTORY
#define EXPRESSION_OP_FACTORY(SYMBOL, OPID)                                                                       \
inline std::shared_ptr<Node> operator SYMBOL (const std::shared_ptr<const Node>& lhs,                             \
                                              const std::shared_ptr<const Node>& rhs) {                           \
  return Expression::Make(Expression::Op::OPID, lhs, rhs);                                                        \
}                                                                                                                 \
                                                                                                                  \
inline std::shared_ptr<Node> operator SYMBOL (const std::shared_ptr<const Node>& lhs,                             \
                                              const Node* rhs) {                                                  \
  return Expression::Make(Expression::Op::OPID, lhs, rhs->shared_from_this());                                    \
}                                                                                                                 \
                                                                                                                  \
inline std::shared_ptr<Node> operator SYMBOL (const std::shared_ptr<const Node>& lhs, int rhs) {                  \
  if (lhs->IsLiteral()) {                                                                                         \
    auto li = std::dynamic_pointer_cast<const Literal>(lhs);                                                      \
    if (li->storage_type() == Literal::StorageType::INT) {                                                        \
      return default_node_pool()->GetLiteral(li->IntValue() SYMBOL rhs);                                           \
    }                                                                                                             \
  }                                                                                                               \
  return lhs SYMBOL intl(rhs);                                                                                    \
}                                                                                                                 \
                                                                                                                  \
inline std::shared_ptr<Node> operator SYMBOL (const Node& lhs, int rhs) {                                         \
  if (lhs.IsLiteral()) {                                                                                          \
    auto& li = dynamic_cast<const Literal&>(lhs);                                                                 \
    if (li.storage_type() == Literal::StorageType::INT) {                                                         \
      return default_node_pool()->GetLiteral(li.IntValue() SYMBOL rhs);                                            \
    }                                                                                                             \
  }                                                                                                               \
  return lhs.shared_from_this() SYMBOL intl(rhs);                                                                 \
}
#endif

EXPRESSION_OP_FACTORY(+, ADD)
EXPRESSION_OP_FACTORY(-, SUB)
EXPRESSION_OP_FACTORY(*, MUL)
EXPRESSION_OP_FACTORY(/, DIV)

}  // namespace cerata
