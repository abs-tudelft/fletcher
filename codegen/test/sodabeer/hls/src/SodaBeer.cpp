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

#include "SodaBeer.h"

bool ChooseDrink(RecordBatchMeta hobbits_meta,
                 Hobbits &hobbits,
                 Hobbits &soda,
                 Hobbits &beer,
                 unsigned int beer_allowed_age) {
#pragma HLS INTERFACE register port=beer_allowed_age
#pragma HLS INTERFACE register port=hobbits_meta.length
#pragma HLS INTERFACE ap_fifo port=hobbits.name_length
#pragma HLS data_pack variable=hobbits.name_length
#pragma HLS INTERFACE ap_fifo port=hobbits.name_chars
#pragma HLS data_pack variable=hobbits.name_chars
#pragma HLS INTERFACE ap_fifo port=hobbits.age
#pragma HLS data_pack variable=hobbits.age
#pragma HLS INTERFACE ap_fifo port=soda.name_length
#pragma HLS data_pack variable=soda.name_length
#pragma HLS INTERFACE ap_fifo port=soda.name_chars
#pragma HLS data_pack variable=soda.name_chars
#pragma HLS INTERFACE ap_fifo port=soda.age
#pragma HLS data_pack variable=soda.age
#pragma HLS INTERFACE ap_fifo port=beer.name_length
#pragma HLS data_pack variable=beer.name_length
#pragma HLS INTERFACE ap_fifo port=beer.name_chars
#pragma HLS data_pack variable=beer.name_chars
#pragma HLS INTERFACE ap_fifo port=beer.age
#pragma HLS data_pack variable=beer.age

  static int i = 0;

  f_uint8 name[MAX_STRING_LENGTH];
  f_size nlen;
  f_uint8 age;

  i++;

  // Select input stream and pull in a Hobbit.
  hobbits.age >> age;
  hobbits.name_lengths >> nlen;
  PullString(name, nlen, hobbits.name_chars);

  // Select output stream and push the Hobbit.
  if (age.data >= beer_allowed_age) {
    beer.age << age;
    beer.name_lengths << nlen;
    PushString(name, nlen, beer.name_chars);
  } else {
    soda.age << age;
    soda.name_lengths << nlen;
    PushString(name, nlen, soda.name_chars);
  }

  if (i == hobbits_meta.length) {
    age.dvalid = false;
    age.last = true;
    nlen.SetDataValid(false);
    nlen.last = true;
    if (age.data >= beer_allowed_age) {
      soda.age << age;
      soda.name_lengths << nlen;
    } else {
      beer.age << age;
      beer.name_lengths << nlen;
    }
  }

  return true;
}
