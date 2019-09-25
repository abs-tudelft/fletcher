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

#include <memory>

#include "cerata/expression.h"

namespace cerata {

std::shared_ptr<Expression> Expression::Make(Op op, std::shared_ptr<const Node> lhs, std::shared_ptr<const Node> rhs) {
  auto e = new Expression(op, std::move(lhs), std::move(rhs));
  return std::shared_ptr<Expression>(e);
}

Expression::Expression(Expression::Op op, std::shared_ptr<const Node> lhs, std::shared_ptr<const Node> rhs)
    : MultiOutputNode(::cerata::ToString(op), NodeID::EXPRESSION, string()),
      operation_(op),
      lhs_(std::move(lhs)),
      rhs_(std::move(rhs)) {}

std::shared_ptr<const Node> Expression::MergeIntLiterals(const Expression *exp) {
  if (exp->lhs_->IsLiteral() && exp->rhs_->IsLiteral()) {
    auto l = std::dynamic_pointer_cast<const Literal>(exp->lhs_);
    auto r = std::dynamic_pointer_cast<const Literal>(exp->rhs_);
    if ((l->storage_type() == Literal::StorageType::INT)
        && (r->storage_type() == Literal::StorageType::INT)
        && (l->type() == r->type())) {
      std::shared_ptr<Node> new_node;
      switch (exp->operation_) {
        case Op::ADD: return intl(l->IntValue() + r->IntValue());
        case Op::SUB: return intl(l->IntValue() - r->IntValue());
        case Op::MUL: return intl(l->IntValue() * r->IntValue());
        case Op::DIV: return intl(l->IntValue() / r->IntValue());
      }
    }
  }
  return exp->shared_from_this();
}

std::shared_ptr<const Node> Expression::EliminateZeroOne(const Expression *exp) {
  switch (exp->operation_) {
    case Op::ADD: {
      if (exp->lhs_ == intl(0)) return exp->rhs_;
      if (exp->rhs_ == intl(0)) return exp->lhs_;
      break;
    }
    case Op::SUB: {
      if (exp->rhs_ == intl(0)) return exp->lhs_;
      break;
    }
    case Op::MUL: {
      if (exp->lhs_ == intl(0)) return intl(0);
      if (exp->rhs_ == intl(0)) return intl(0);
      if (exp->lhs_ == intl(1)) return exp->rhs_;
      if (exp->rhs_ == intl(1)) return exp->lhs_;
      break;
    }
    case Op::DIV: {
      if (exp->lhs_ == intl(0) && exp->rhs_ != intl(0)) return intl(0);
      if (exp->rhs_ == intl(0)) { CERATA_LOG(FATAL, "Division by 0."); }
      if (exp->rhs_ == intl(1)) return exp->lhs_;
      break;
    }
  }
  return exp->shared_from_this();
}

std::shared_ptr<const Node> Expression::Minimize(const Node *node) {
  std::shared_ptr<const Node> result = node->shared_from_this();

  // If this node is an expression, we need to mimize its lhs and rhs first.
  if (node->IsExpression()) {
    auto expr = std::dynamic_pointer_cast<const Expression>(result);
    // Attempt to minimize children.
    auto min_lhs = Minimize(expr->lhs());
    auto min_rhs = Minimize(expr->rhs());

    // If minimization took place in either node, create a new expression with the minimized nodes.
    if ((min_lhs != expr->lhs_) || (min_rhs != expr->rhs_)) {
      expr = Expression::Make(expr->operation_, min_lhs, min_rhs);
    }

    // Apply zero/one elimination on the minimized expression.
    result = EliminateZeroOne(expr.get());

    // Integer literal merging
    if (result->IsExpression()) {
      expr = std::dynamic_pointer_cast<const Expression>(result);
      result = MergeIntLiterals(expr.get());
    }
    // TODO(johanpel): put some more elaborate minimization function/rules etc.. here
  }
  return result;
}

std::string ToString(Expression::Op operation) {
  switch (operation) {
    case Expression::Op::ADD:return "+";
    case Expression::Op::SUB:return "-";
    case Expression::Op::MUL:return "*";
    case Expression::Op::DIV:return "/";
    default:return "INVALID OP";
  }
}

std::string Expression::ToString() const {
  auto min = Minimize(this);
  if (min->IsExpression()) {
    auto mine = std::dynamic_pointer_cast<const Expression>(min);
    auto ls = mine->lhs_->ToString();
    auto op = cerata::ToString(operation_);
    auto rs = mine->rhs_->ToString();
    return ls + op + rs;
  } else {
    return min->ToString();
  }
}

std::shared_ptr<Object> Expression::Copy() const {
  return Expression::Make(operation_,
                          std::dynamic_pointer_cast<Node>(lhs_->Copy()),
                          std::dynamic_pointer_cast<Node>(rhs_->Copy()));
}

std::shared_ptr<Edge> Expression::AddSource(Node *source) {
  CERATA_LOG(FATAL, "Cannot drive an expression node.");
  return nullptr;
}

}  // namespace cerata
