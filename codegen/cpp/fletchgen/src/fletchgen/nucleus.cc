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

#include "fletchgen/nucleus.h"

#include <utility>
#include <vector>
#include <string>

#include "fletchgen/basic_types.h"
#include "fletchgen/recordbatch.h"
#include "fletchgen/kernel.h"
#include "fletchgen/mmio.h"

namespace fletchgen {

ArrayCmdCtrlMerger::ArrayCmdCtrlMerger() : Component("ArrayCmdCtrlMerger") {
  // This is a primitive component from the hardware lib
  meta_[cerata::vhdl::metakeys::PRIMITIVE] = "true";
  meta_[cerata::vhdl::metakeys::LIBRARY] = "work";
  meta_[cerata::vhdl::metakeys::PACKAGE] = "Array_pkg";

  auto reg64 = cerata::Vector::Make(64);
  auto baw = Parameter::Make("bus_addr_width", integer(), intl(64));
  auto idw = Parameter::Make("index_width", integer(), intl(32));
  auto tw = Parameter::Make("tag_width", integer(), intl(1));
  auto cw = Parameter::Make("num_addr", integer(), intl(0));
  auto nucleus_side_cmd = Port::Make("nucleus_cmd", cmd(tw, cw), Port::Dir::OUT, kernel_cd());
  auto kernel_side_cmd = Port::Make("kernel_cmd", cmd(tw), Port::Dir::IN, kernel_cd());
  auto ctrl = PortArray::Make("ctrl", reg64, cw, Port::Dir::IN, kernel_cd());
  Add({baw, idw, tw, nucleus_side_cmd, kernel_side_cmd, ctrl});
}

std::unique_ptr<Instance> ArrayCmdCtrlMergerInstance(const std::string &name) {
  std::unique_ptr<Instance> result;
  // Check if the Array component was already created.
  Component *merger_comp;
  auto optional_component = cerata::default_component_pool()->Get("ArrayCmdCtrlMerger");
  if (optional_component) {
    merger_comp = *optional_component;
  } else {
    auto merger_comp_shared = std::make_shared<ArrayCmdCtrlMerger>();
    cerata::default_component_pool()->Add(merger_comp_shared);
    merger_comp = merger_comp_shared.get();
  }
  // Create and return an instance of the Array component.
  result = Instance::Make(merger_comp, name);
  return result;
}

static void CopyFieldPorts(Component *nucleus,
                           Component *kernel,
                           const RecordBatch &record_batch,
                           FieldPort::Function fun) {
  // Add Arrow field derived ports with some function.
  auto field_ports = record_batch.GetFieldPorts(fun);
  for (const auto &fp : field_ports) {
    // Create a copy and invert for the Nucleus
    auto copied_port = std::dynamic_pointer_cast<FieldPort>(fp->Copy());
    copied_port->InvertDirection();
    nucleus->Add(copied_port);
    // Create and add another copy for the kernel component
    kernel->Add(copied_port->Copy());
  }
}

Nucleus::Nucleus(const std::string &name,
                 const std::deque<RecordBatch *> &recordbatches,
                 const std::vector<fletcher::RecordBatchDescription> &batch_desc,
                 const std::vector<MmioReg> &custom_regs)
    : Component("Nucleus_" + name) {

  // TODO(johanpel): move this sanity check to where it should be
  if (recordbatches.size() != batch_desc.size()) {
    throw std::runtime_error("Number of recordbatch components not equal to recordbatch descriptors.");
  }

  // Add address width
  Add(bus_addr_width());

  // Add clock/reset
  auto kcd = Port::Make("kcd", cr(), Port::Dir::IN, kernel_cd());
  Add(kcd);

  // Create kernel
  kernel = Kernel::Make(name, this);

  // Add MMIO port
  auto mmio = MmioPort::Make(Port::Dir::IN);
  Add(mmio);

  // Add VHDMMIO component
  std::vector<std::string> vhdmmio_buf_port_names;
  auto vhdmmio = GenerateMmioComponent(batch_desc, custom_regs, &vhdmmio_buf_port_names);
  auto vhdmmio_inst = AddInstanceOf(vhdmmio.get());

  vhdmmio_inst->port("mmio") <<= mmio;
  vhdmmio_inst->port("kcd") <<= kcd;

  // Add ports from mmio
  for (const auto &p : vhdmmio_inst->GetAll<Port>()) {
    if (p->meta.count(MMIO_KERNEL) > 0) {
      auto name_intended = p->meta.at(MMIO_KERNEL);
      auto kernel_mmio_port = std::dynamic_pointer_cast<Port>(p->Copy());
      kernel_mmio_port->InvertDirection();
      kernel_mmio_port->SetName(name_intended);
      kernel->Add(kernel_mmio_port);
    }
  }

  std::vector<Instance *> accms;

  // Add ports going to/from RecordBatches
  for (auto r : recordbatches) {
    // Just copy over the Arrow data and unlock stream ports. Their fields are not abstracted for the kernel user.
    CopyFieldPorts(this, kernel.get(), *r, FieldPort::Function::ARROW);
    CopyFieldPorts(this, kernel.get(), *r, FieldPort::Function::UNLOCK);

    // For the kernel user, we need to abstract the "ctrl" field of the command stream away.
    // Because TODO(johanpel): flat type slicing isn't implemented
    // we need to instantiate a little component that just adds the buffer addresses to the ctrl stream.

    // First, obtain all command stream ports.
    auto cmd_ports = r->GetFieldPorts(FieldPort::Function::COMMAND);
    for (auto &cp : cmd_ports) {
      // For each one of them, make an inverted copy of the recordbatch unabstracted command stream port. This one will
      // expose all command stream fields to the nucleus user.
      auto nucleus_cmd = std::dynamic_pointer_cast<FieldPort>(cp->Copy());
      nucleus_cmd->InvertDirection();
      Add(nucleus_cmd);

      // Next, make an abstracted version of the command stream for the kernel user.
      auto kernel_cmd = FieldPort::MakeCommandPort(cp->fletcher_schema_, cp->field_, false, kernel_cd());
      kernel_cmd->InvertDirection();
      kernel->Add(kernel_cmd);

      // Now, create a dirty little ACCM to solve this issue.
      // This is dirty in the sense that the addresses are actually not streams, so there is no synchronization.
      auto accm_inst = ArrayCmdCtrlMergerInstance(cp->name() + "_accm_inst");
      accms.push_back(accm_inst.get());
      // Move ownership to this component.
      this->AddChild(std::move(accm_inst));
    }
  }

  // Instantiate the kernel
  kernel_inst = AddInstanceOf(kernel.get());

  // Connect clock domain.
  Connect(kernel_inst->port("kcd"), kcd.get());

  // Perform some magic to abstract the buffer addresses away from the ctrl stream at the kernel level.
  // First, obtain the intended name for the kernel from the metadata of the vhdmmio component port metadata.
  // Then, make a connection between these two components.
  for (auto &p : vhdmmio_inst->GetAll<Port>()) {
    if (p->meta.count(MMIO_KERNEL) > 0) {
      auto name_intended = p->meta.at(MMIO_KERNEL);
      auto inst_port = kernel_inst->port(name_intended);
      if (p->dir() == Port::Dir::OUT) {
        Connect(inst_port, p);
      } else {
        Connect(p, inst_port);
      }
    }
  }

  // Connect all recordbatch ports
  size_t batch_idx = 0;
  size_t accm_idx = 0;
  size_t buf_idx = 0;
  for (const auto &r : recordbatches) {
    // Connect Arrow data stream
    for (const auto &ap : r->GetFieldPorts(FieldPort::Function::ARROW)) {
      auto kernel_data = kernel_inst->port(ap->name());
      auto nucleus_data = port(ap->name());
      if (ap->dir() == Port::OUT) {
        Connect(kernel_data, nucleus_data);
      } else {
        Connect(nucleus_data, kernel_data);
      }
    }

    // Connect unlock stream
    for (const auto &up : r->GetFieldPorts(FieldPort::Function::UNLOCK)) {
      auto kernel_unl = kernel_inst->port(up->name());
      auto nucleus_unl = port(up->name());
      Connect(kernel_unl, nucleus_unl);
    }

    // Connect the command stream through the ACCM.
    size_t field_idx = 0;
    for (const auto &cp : r->GetFieldPorts(FieldPort::Function::COMMAND)) {
      auto accm_nucleus_cmd = accms[accm_idx]->port("nucleus_cmd");
      auto accm_kernel_cmd = accms[accm_idx]->port("kernel_cmd");
      auto accm_ctrl = accms[accm_idx]->porta("ctrl");

      auto nucleus_cmd = port(cp->name());
      auto kernel_cmd = kernel_inst->port(cp->name());

      Connect(nucleus_cmd, accm_nucleus_cmd);
      Connect(accm_kernel_cmd, kernel_cmd);

      auto field_bufs = batch_desc[batch_idx].fields[field_idx].buffers;
      for (size_t b = 0; b < field_bufs.size(); b++) {
        auto vhdmmio_buf_addr = vhdmmio_inst->port("f_" + vhdmmio_buf_port_names[buf_idx] + "_data");
        Connect(accm_ctrl->Append(), vhdmmio_buf_addr);
        buf_idx++;
      }
      field_idx++;
      accm_idx++;
    }
    batch_idx++;
  }
}

std::shared_ptr<Nucleus> Nucleus::Make(const std::string &name,
                                       const std::deque<RecordBatch *> &recordbatches,
                                       const std::vector<fletcher::RecordBatchDescription> &batch_desc,
                                       const std::vector<MmioReg> &custom_regs) {
  return std::make_shared<Nucleus>(name, recordbatches, batch_desc, custom_regs);
}

}  // namespace fletchgen
