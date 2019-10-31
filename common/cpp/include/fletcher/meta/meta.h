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

namespace fletcher {

/// Namespace used to define and explain keys and potentially values for schemas and fields.
namespace meta {

// Schema metadata:

constexpr char TRUE[] = "true";
constexpr char FALSE[] = "false";

/// Schema name.
constexpr char NAME[] = "fletcher_name";

/// Schema mode.
/// Can be either "read" or "write".
constexpr char MODE[] = "fletcher_mode";
constexpr char READ[] = "read";
constexpr char WRITE[] = "write";

/// Key to set the bus specification of a schema (future releases: fields or even sub-streams of fields).
///
/// Value must be a tuple of the following form: "aw,dw,lw,bs,bm" where:
///
/// aw : Bus address width
/// dw : Bus data width
/// lw : Bus burst length width
/// bs : Bus minimum burst size
/// bm : Bus maximum burst size
///
/// All values should be supplied as a decimal ASCII string.
constexpr char BUS_SPEC[] = "fletcher_bus_spec";

// Field metadata:

/// Key to enable profiling of data streams.
/// Setting value to "true" enables profiling. Any other value disables profiling.
constexpr char PROFILE[] = "fletcher_profile";

/// Key to ignore a schema field.
/// Setting value to "true" ignores this field in generation / run-time.
constexpr char IGNORE[] = "fletcher_ignore";

/// Key to set value elements per cycle.
/// Values can be any natural power of two, e.g. "1", "2", "4", ...
constexpr char VALUE_EPC[] = "fletcher_epc";

/// Key to set list elements per cycle.
/// Values can be any natural power of two, e.g. "1", "2", "4", ...
constexpr char LIST_EPC[] = "fletcher_lepc";

/// Key to set the tag width for the command and unlock streams.
/// Values can by any positive, e.g. "1", "2", "3", ...
constexpr char TAG_WIDTH[] = "fletcher_tag_width";

}
}
