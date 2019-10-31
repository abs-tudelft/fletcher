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

#include "fletchgen/profiler.h"

#include <cerata/api.h>
#include <cmath>
#include <memory>
#include <vector>
#include <tuple>

#include "fletchgen/basic_types.h"
#include "fletchgen/nucleus.h"

namespace fletchgen {

using cerata::component;
using cerata::parameter;
using cerata::port;
using cerata::stream;
using cerata::vector;
using cerata::record;
using cerata::field;
using cerata::integer;
using cerata::bit;

static constexpr uint32_t COUNT_WIDTH = 32;

// Vhdmmio documentation strings for profiling:
namespace doc {
static constexpr char e[] = "Element count. Accumulates the number of elements transferred on the stream. "
                            "Writing to the register subtracts the written value.";
static constexpr char v[] = "Valid count. Increments each cycle that the stream is valid. "
                            "Writing to the register subtracts the written value.";
static constexpr char r[] = "Ready count. Increments each cycle that the stream is ready. "
                            "Writing to the register subtracts the written value.";
static constexpr char t[] = "Transfer count. "
                            "Increments for each transfer on the stream, i.e. when it is handshaked. "
                            "Writing to the register subtracts the written value.";
static constexpr char p[] = "Packet count. Increments each time the last signal is set during a handshake "
                            "Writing to the register subtracts the written value.";
static constexpr char c[] = "Cycle count. Increments each clock cycle while profiler is enabled.";
}  // namespace doc

namespace name {
static constexpr char e[] = "elements";
static constexpr char v[] = "valids";
static constexpr char r[] = "readies";
static constexpr char t[] = "transfers";
static constexpr char p[] = "packets";
static constexpr char c[] = "cycles";
}  // namespace name

std::vector<MmioReg> GetProfilingRegs(const std::vector<std::shared_ptr<RecordBatch>> &recordbatches) {
  std::vector<MmioReg> profile_regs;
  using MF = MmioFunction;
  using MB = MmioBehavior;

  profile_regs.emplace_back(MF::PROFILE,
                            MB::CONTROL,
                            "Profile_enable",
                            "Activates profiler counting when this bit is high.",
                            1);

  profile_regs.emplace_back(MF::PROFILE,
                            MB::STROBE,
                            "Profile_clear",
                            "Resets profiler counters when this bit is asserted.",
                            1);

  for (const auto &rb : recordbatches) {
    auto fps = rb->GetFieldPorts();
    for (const auto &fp : fps) {
      // Check if we should profile the field-derived port node.
      if (fp->profile_) {
        auto flattened = cerata::Flatten(fp->type());
        int si = 0;  // stream index
        for (auto &fti : flattened) {
          if (dynamic_cast<cerata::Stream *>(fti.type_) != nullptr) {
            const auto pre = "Profile_" + fti.name(cerata::NamePart(fp->name()));  // prefix
            const auto sis = "_" + std::to_string(si) + "_";  // stream index string
            MmioReg e(MF::PROFILE, MB::STATUS, pre + sis + name::e, doc::e, COUNT_WIDTH);
            MmioReg v(MF::PROFILE, MB::STATUS, pre + sis + name::v, doc::v, COUNT_WIDTH);
            MmioReg r(MF::PROFILE, MB::STATUS, pre + sis + name::r, doc::r, COUNT_WIDTH);
            MmioReg t(MF::PROFILE, MB::STATUS, pre + sis + name::t, doc::t, COUNT_WIDTH);
            MmioReg p(MF::PROFILE, MB::STATUS, pre + sis + name::p, doc::p, COUNT_WIDTH);
            MmioReg c(MF::PROFILE, MB::STATUS, pre + sis + name::c, doc::c, COUNT_WIDTH);
            profile_regs.insert(profile_regs.end(), {e, v, r, t, p, c});
            si++;
          }
        }
      }
    }
  }
  return profile_regs;
}

std::shared_ptr<cerata::Type> stream_probe(const std::shared_ptr<Node> &count_width) {
  // We require a probe stream where the valid and ready are control fields that travel in the same direction.
  // flat type indices:
  auto result = stream("probe",                          // 0
                       "count", vector(count_width),     // 4
                       {field(cerata::Stream::valid()),  // 1
                        field(cerata::Stream::ready()),  // 2
                        field(last())});                 // 3
  return result;
}

static Component *profiler() {
  // Check if the Array component was already created.
  auto opt_comp = cerata::default_component_pool()->Get("Profiler");
  if (opt_comp) {
    return *opt_comp;
  }

  // Parameters
  auto icw = parameter("PROBE_COUNT_WIDTH", integer(), cerata::intl(1));
  auto ocw = parameter("OUT_COUNT_WIDTH", integer(), cerata::intl(32));
  auto oct = vector("out_count_type", ocw);

  auto pcr = port("pcd", cr(), Port::Dir::IN);
  auto probe = port("probe", stream_probe(icw), Port::Dir::IN);
  auto enable = port("enable", bit(), Port::Dir::IN);
  auto clear = port("clear", bit(), Port::Dir::IN);
  auto e = port(std::string("count_") + name::e, oct, Port::Dir::OUT);
  auto v = port(std::string("count_") + name::v, oct, Port::Dir::OUT);
  auto r = port(std::string("count_") + name::r, oct, Port::Dir::OUT);
  auto t = port(std::string("count_") + name::t, oct, Port::Dir::OUT);
  auto p = port(std::string("count_") + name::p, oct, Port::Dir::OUT);
  auto c = port(std::string("count_") + name::c, oct, Port::Dir::OUT);

  // Component & ports
  auto ret = component("Profiler", {icw, ocw, pcr, probe, enable, clear, e, v, r, t, p, c});

  // VHDL metadata
  ret->SetMeta(cerata::vhdl::meta::PRIMITIVE, "true");
  ret->SetMeta(cerata::vhdl::meta::LIBRARY, "work");
  ret->SetMeta(cerata::vhdl::meta::PACKAGE, "Profile_pkg");

  return ret.get();
}

NodeProfilerPorts EnableStreamProfiling(cerata::Component *comp,
                                        const std::vector<cerata::Signal *> &profile_nodes) {
  cerata::NodeMap rebinding;
  NodeProfilerPorts result;
  // Get all nodes and check if their type contains a stream, then check if they should be profiled.
  for (auto node : profile_nodes) {
    // Flatten the type
    auto flat_types = Flatten(node->type());
    int s = 0;
    // Iterate over all flattened types. If we encounter a stream, we must profile it.
    size_t fti = 0;
    while (fti < flat_types.size()) {
      if (flat_types[fti].type_->Is(Type::RECORD)) {
        FLETCHER_LOG(DEBUG, "Inserting profiler for stream node " + node->name()
            + ", sub-stream " + std::to_string(s)
            + " of flattened type " + node->type()->name()
            + " index " + std::to_string(fti) + ".");
        // Signal must have domain, so we should be able to immediately get optional value.
        auto domain = *GetDomain(*node);
        auto cr_node = GetClockResetPort(comp, *domain);
        if (!cr_node) {
          throw std::runtime_error("No clock/reset port present on component [" + comp->name()
                                       + "] for clock domain [" + domain->name()
                                       + "] of stream node [" + node->name() + "].");
        }

        // Instantiate a profiler.
        std::string name = flat_types[fti].name(cerata::NamePart(node->name(), true));
        auto profiler_inst = comp->Instantiate(profiler(), profiler()->name() + "_" + name + "_inst");
        // Set the domain of all ports.
        for (auto &p : profiler_inst->GetAll<Port>()) {
          p->SetDomain(domain);
        }

        // Obtain profiler ports.
        auto p_probe = profiler_inst->prt("probe");
        auto p_cr = profiler_inst->prt("pcd");
        auto p_in_count_width = profiler_inst->par("PROBE_COUNT_WIDTH");

        // Set up a type mapper.
        auto mapper = TypeMapper::Make(node->type(), p_probe->type());
        auto matrix = mapper->map_matrix().Empty();
        matrix(fti, 0) = 1;    // Connect the stream record.
        matrix(++fti, 1) = 1;  // Connect the stream valid.
        matrix(++fti, 2) = 1;  // Connect the stream ready.

        // Now we need to find field marked with "count" metadata for EPC streams, if it exists.
        // Increase the flat type field index, until we hit the next stream, or we see a field with metadata meant for
        // this function.

        // Go the next flat type index.
        // If there is any flat types left, figure out where the count and last fields are.
        fti++;
        while (fti < flat_types.size()) {
          auto ft = flat_types[fti];
          if (ft.type_->meta.count(meta::COUNT) > 0) {
            auto width = std::strtol(flat_types[fti].type_->meta.at(meta::COUNT).c_str(), nullptr, 10);
            p_in_count_width <<= intl(static_cast<int>(width));
            // We've found the count field.
            matrix(fti, 4) = 1;  // Connect the count.
          }
          if (ft.type_->meta.count(meta::LAST) > 0) {
            matrix(fti, 3) = 1;  // Connect the last bit.
          }
          fti++;
        }
        // Set the mapping matrix of the new mapper, and add it to the probe.
        mapper->SetMappingMatrix(matrix);
        node->type()->AddMapper(mapper);

        // Connect the clock/reset, probe and profile output.
        Connect(p_cr, *cr_node);
        Connect(p_probe, node);

        // Create an entry in the map.
        auto new_ports = std::vector<Port *>({profiler_inst->prt(std::string("count_") + name::e),
                                              profiler_inst->prt(std::string("count_") + name::v),
                                              profiler_inst->prt(std::string("count_") + name::r),
                                              profiler_inst->prt(std::string("count_") + name::t),
                                              profiler_inst->prt(std::string("count_") + name::p),
                                              profiler_inst->prt(std::string("count_") + name::c)});

        if (result.count(node) == 0) {
          // We need to create a new entry.
          result[node] = {{profiler_inst}, new_ports};
        } else {
          // Insert the ports into the old entry.
          result[node].first.push_back(profiler_inst);
          auto vec = result[node].second;
          vec.insert(vec.end(), new_ports.begin(), new_ports.end());
        }
        // Increase the s-th stream index in the flattened type.
        s++;
      } else {
        // Not a stream, just continue.
        fti++;
      }
    }
  }
  return result;
}

}  // namespace fletchgen
