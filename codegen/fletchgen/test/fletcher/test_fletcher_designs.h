#pragma once

#include <memory>

#include "../../src/edges.h"
#include "../../src/types.h"
#include "../../src/nodes.h"
#include "../../src/graphs.h"

#include "../../src/hardware/basic_types.h"
#include "../../src/hardware/bus.h"
#include "../../src/hardware/column.h"
#include "../../src/hardware/mantle.h"

namespace fletchgen {
namespace hardware {

std::shared_ptr<Component> GetColumnReadersAndArbiter() {
  auto top = Component::Make("top");

  auto cr0 = Instance::Make("cr0", ColumnReader());
  auto cr1 = Instance::Make("cr1", ColumnReader());
  auto bra = Instance::Make("bra", BusReadArbiter());

  std::shared_ptr<Node> bra_rreq = bra->ap("bsv_rreq");
  std::shared_ptr<Node> cr0_rreq = cr0->Get(Node::PORT, "bus_rreq");
  std::shared_ptr<Node> cr1_rreq = cr1->Get(Node::PORT, "bus_rreq");

  std::shared_ptr<Node> bra_rdat = bra->ap("bsv_rdat");
  std::shared_ptr<Node> cr0_rdat = cr0->Get(Node::PORT, "bus_rdat");
  std::shared_ptr<Node> cr1_rdat = cr1->Get(Node::PORT, "bus_rdat");

  bra_rreq <<= cr0_rreq;
  bra_rreq <<= cr1_rreq;

  bra_rdat <<= cr0_rdat;
  bra_rdat <<= cr1_rdat;

  top->AddChild(bra)
      .AddChild(cr0)
      .AddChild(cr1);

  return top;
}

}
}