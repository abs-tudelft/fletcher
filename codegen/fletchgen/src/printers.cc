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

#include <iostream>

#include "printers.h"

using vhdl::t;

namespace fletchgen {

std::string getFieldInfoString(arrow::Field *field, ArrowStream *parent) {
  std::string ret;

  int epc = getEPC(field);

  int l = 0;

  if (parent != nullptr) {
    l = parent->depth() + 1;
  }

  ret += t(l) + "<Field>: ";
  ret += field->name() + "\n";

  if (parent != nullptr) {
    if (parent->isStruct())
      ret += t(l + 1) + "Struct child.\n";
    if (parent->isList())
      ret += t(l + 1) + "List child.\n";
  }
  if (field->nullable())
    ret += t(l + 1) + "Nullable.\n";

  ret += t(l + 1) + "Type: " + field->type()->ToString() + "\n";
  ret += t(l + 1) + "Width: " + getWidth(field->type().get()).toString() + "\n";

  if ((epc != 1) && (field->type()->id() != arrow::Type::BINARY) && (field->type()->id() != arrow::Type::STRING)) {
    ret += t(l + 1) + "EPC: " + std::to_string(epc) + "\n";
  }

  if (field->type()->num_children() > 0) {
    ret += t(l + 1) + "Children: " + std::to_string(field->type()->num_children()) + "\n";
  }

  ret.pop_back();
  return ret;
}

std::string HexView::toString(bool header) {
  char buf[6] = {0};
  std::string ret;
  if (header) {
    ret = "                  ";
    for (uint i = 0; i < width; i++) {
      sprintf(buf, "%02X ", i);
      ret.append(buf);
    }
  }
  ret.append(str);
  return ret;
}

unsigned char convertToReadable(unsigned char c) {
  if ((c < 32) || (c > 126)) {
    return '.';
  }
  return c;
}

void HexView::addData(const uint8_t *ptr, size_t size) {
  char buf[64] = {0};
  std::string left;
  std::string right;

  uint i = 0;

  while (i < size) {
    if (col % width == 0) {
      str.append(left);
      str.append(" ");
      str.append(right);
      str.append("\n");
      left = "";
      right = "";
      sprintf(buf, "%016lX: ", start + row * width);
      left.append(buf);
      row++;
    }

    sprintf(buf, "%02X", (unsigned char) ptr[i]);
    left.append(buf);

    sprintf(buf, "%c", convertToReadable((unsigned char) ptr[i]));
    right.append(buf);

    if (i == size - 1) {
      left.append("|");
    } else {
      left.append(" ");
    }
    col++;
    i++;
  }

  left.append(std::string(18+3*width - left.length(), ' '));

  str.append(left);
  str.append(" ");
  str.append(right);
  str.append("\n");
}

HexView::HexView(unsigned long start, std::string str, unsigned long row, unsigned long col, unsigned long width) : str(
    std::move(str)), row(row), col(col), width(width), start(start) {}

}