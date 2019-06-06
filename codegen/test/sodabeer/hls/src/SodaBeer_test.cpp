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

#include <vector>
#include <string>

#include "SodaBeer.h"

void ListHobbits(Hobbits &soda) {
  f_uint8 age;
  f_size length;
  f_uint8 c;
  while (!soda.age.empty()) {
    soda.age >> age;
    soda.name_lengths >> length;
    if (age.DataValid() && length.DataValid()) {
      for (int j = 0; j < length.data; j++) {
        soda.name_chars >> c;
        putchar(c.data);
        if (c.last) {
          putchar('.');
        }
      }
      std::cout << "[name length=" << length.data
                << ", name last=" << length.last
                << ", age=" << age.data
                << " last=" << age.last
                << "]\n";
    } else {
      std::cout << "<empty> [dvalid=0, last=" << age.last << "]" << std::endl;
    }
  }
}

int main() {
  std::vector<std::string> hobbits_names = {"Bilbo", "Sam", "Rosie", "Frodo", "Elanor", "Lobelia", "Merry", "Pippin"};
  std::vector<uint8_t> hobbits_ages = {111, 35, 32, 33, 1, 80, 37, 29};

  RecordBatchMeta meta = {8};
  Hobbits hobbits;
  Hobbits soda;
  Hobbits beer;

  for (int i = 0; i < hobbits_names.size(); i++) {
    f_uint8 age;
    age.data = hobbits_ages[i];
    age.last = i == hobbits_names.size() - 1;
    age.dvalid = 1;
    hobbits.age << age;

    f_size len;
    len.data = hobbits_names[i].size();
    len.last = i == hobbits_names.size() - 1;
    len.dvalid = 1;
    hobbits.name_lengths << len;

    for (int j = 0; j < hobbits_names[i].size(); j++) {
      f_uint8 ch;
      ch.data = hobbits_names[i].c_str()[j];
      ch.last = j == hobbits_names[i].size() - 1;
      ch.dvalid = 1;
      hobbits.name_chars << ch;
    }
    ChooseDrink(meta, hobbits, soda, beer, 33);
  }

  printf("Hobbits drinking soda:\n");
  ListHobbits(soda);

  printf("Hobbits drinking beer:\n");
  ListHobbits(beer);
}
