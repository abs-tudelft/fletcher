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

#include <memory>
#include <utility>

#include "cerata/expression.h"
#include "cerata/graph.h"

namespace cerata {

static std::string ToString(Node *n) {
  std::stringstream ss;
  ss << n;
  return ss.str();
}

static std::string ToString(const std::shared_ptr<Node>& n) {
  std::stringstream ss;
  ss << n;
  return ss.str();
}

std::shared_ptr<Expression> Expression::Make(Op op, std::shared_ptr<Node> lhs, std::shared_ptr<Node> rhs) {
  auto e = new Expression(op, std::move(lhs), std::move(rhs));
  auto result = std::shared_ptr<Expression>(e);
  if (e->parent()) {
    e->parent().value()->Add(result);
  }
  return result;
}

// Hash the the node pointers into a short string.
static std::string GenerateName(Expression *expr, std::shared_ptr<Node> lhs, std::shared_ptr<Node> rhs) {
  auto l = ::cerata::ToString(std::move(lhs));
  auto e = ::cerata::ToString(expr);
  auto r = ::cerata::ToString(std::move(rhs));
  std::string result = "Expr_" + l + e + r;
  return result;
}

Expression::Expression(Expression::Op op, std::shared_ptr<Node> lhs, std::shared_ptr<Node> rhs)
    : MultiOutputNode(GenerateName(this, lhs, rhs), NodeID::EXPRESSION, string()),
      operation_(op),
      lhs_(std::move(lhs)),
      rhs_(std::move(rhs)) {
  if (lhs_->parent() && rhs_->parent()) {
    auto lp = *lhs_->parent();
    auto rp = *rhs_->parent();
    if (lp != rp) {
      CERATA_LOG(ERROR, "Can only generate expressions between nodes on same parent.");
    }
  }
  if (lhs_->parent()) {
    auto lp = *lhs_->parent();
    SetParent(lp);
  } else if (rhs_->parent()) {
    auto rp = *rhs_->parent();
    SetParent(rp);
  }
}

std::shared_ptr<Node> Expression::MergeIntLiterals(Expression *exp) {
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

std::shared_ptr<Node> Expression::EliminateZeroOne(Expression *exp) {
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

std::shared_ptr<Node> Expression::Minimize(Node *node) {
  std::shared_ptr<Node> result = node->shared_from_this();

  // If this node is an expression, we need to minimize its lhs and rhs first.
  if (node->IsExpression()) {
    auto expr = std::dynamic_pointer_cast<Expression>(result);
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
      expr = std::dynamic_pointer_cast<Expression>(result);
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
  }
  return "INVALID OP";
}

std::string Expression::ToString() const {
  auto min = Minimize(const_cast<Expression *>(this));
  if (min->IsExpression()) {
    auto mine = std::dynamic_pointer_cast<Expression>(min);
    auto ls = mine->lhs_->ToString();
    auto op = cerata::ToString(mine->operation_);
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

Node *Expression::CopyOnto(Graph *dst, const std::string &name, NodeMap *rebinding) const {
  auto new_lhs = this->lhs_;
  auto new_rhs = this->rhs_;
  ImplicitlyRebindNodes(dst, {lhs_.get(), rhs_.get()}, rebinding);
  // Check for both sides if they were already in the rebind map.
  // If not, make copies onto the graph for those nodes as well.
  if (rebinding->count(lhs_.get()) > 0) {
    new_lhs = rebinding->at(lhs_.get())->shared_from_this();
  } else {
    new_lhs = lhs_->CopyOnto(dst, lhs_->name(), rebinding)->shared_from_this();
  }
  if (rebinding->count(rhs_.get()) > 0) {
    new_rhs = rebinding->at(rhs_.get())->shared_from_this();
  } else {
    new_rhs = rhs_->CopyOnto(dst, rhs_->name(), rebinding)->shared_from_this();
  }
  auto result = Expression::Make(operation_, new_lhs, new_rhs);
  (*rebinding)[this] = result.get();
  dst->Add(result);
  return result.get();
}

void Expression::AppendReferences(std::vector<Object *> *out) const {
  out->push_back(lhs_.get());
  lhs_->AppendReferences(out);
  out->push_back(rhs_.get());
  rhs_->AppendReferences(out);
}

}  // namespace cerata
