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
using cerata::bool_true;
using cerata::bool_false;
using cerata::RecField;
using cerata::Vector;
using cerata::Record;
using cerata::Stream;

std::shared_ptr<Type> mmio(MmioSpec spec) {
  auto result = Record::Make("mmio", {
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
  return result;
}

std::string MmioSpec::ToString() const {
  std::stringstream str;
  str << "MmioSpec[";
  str << "addr:" << addr_width;
  str << ", dat:" << data_width;
  str << "]";
  return str.str();
}

}  // namespace fletchgen
