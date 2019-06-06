// Copyright 2019 Delft University of Technology
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

#include <hls_stream.h>
#include <hls_math.h>
#include <ap_int.h>

#include "fletcher/vivado_hls.h"

struct Hobbits {
	hls::stream<f_size> name_lengths;
	hls::stream<f_uint8> name_chars;
	hls::stream<f_uint8> age;
};

bool ChooseDrink(RecordBatchMeta hobbits_meta, Hobbits& hobbits, Hobbits& soda, Hobbits& beer, unsigned int beer_allowed_age);
