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

#include "fletchgen/mmio.h"

#include <cerata/api.h>
#include <fletcher/logging.h>
#include <memory>
#include <string>

namespace fletchgen {

using cerata::Parameter;
using cerata::Port;
using cerata::PortArray;
using cerata::intl;
using cerata::integer;
using cerata::string;
using cerata::strl;
using cerata::boolean;
using cerata::integer;
using cerata::bit;
using cerata::RecField;
using cerata::Vector;
using cerata::Record;
using cerata::Stream;

std::shared_ptr<Type> mmio(MmioSpec spec) {
  auto mmio_typename = spec.ToMMIOTypeName();
  auto optional_existing_mmio_type = cerata::default_type_pool()->Get(mmio_typename);
  if (optional_existing_mmio_type) {
    FLETCHER_LOG(DEBUG, "MMIO Type already exists in default pool.");
    return optional_existing_mmio_type.value()->shared_from_this();
  } else {
    auto new_mmio_type = Record::Make(mmio_typename, {
        NoSep(RecField::Make("aw", Stream::Make(Record::Make("aw", {
            RecField::Make("addr", Vector::Make(spec.addr_width))})))),
        NoSep(RecField::Make("w", Stream::Make(Record::Make("w", {
            RecField::Make("data", Vector::Make(spec.data_width)),
            RecField::Make("strb", Vector::Make(spec.data_width / 8))
        })))),
        NoSep(RecField::Make("b", Stream::Make(Record::Make("b", {
            RecField::Make("resp", Vector::Make(2))})), true)),
        NoSep(RecField::Make("ar", Stream::Make(Record::Make("ar", {
            RecField::Make("addr", Vector::Make(spec.addr_width))
        })))),
        NoSep(RecField::Make("r", Stream::Make(Record::Make("r", {
            RecField::Make("data", Vector::Make(spec.data_width)),
            RecField::Make("resp", Vector::Make(2))})), true)),
    });
    cerata::default_type_pool()->Add(new_mmio_type);
    return new_mmio_type;
  }
}

std::string MmioSpec::ToString() const {
  std::stringstream str;
  str << "MmioSpec[";
  str << "addr:" << addr_width;
  str << ", dat:" << data_width;
  str << "]";
  return str.str();
}

std::string MmioSpec::ToMMIOTypeName() const {
  std::stringstream str;
  str << "MMIO";
  str << "_A" << addr_width;
  str << "_D" << data_width;
  return str.str();
}

std::shared_ptr<MmioPort> MmioPort::Make(Port::Dir dir, MmioSpec spec, const std::shared_ptr<ClockDomain> &domain) {
  return std::make_shared<MmioPort>(dir, spec, "mmio", domain);
}

}  // namespace fletchgen
