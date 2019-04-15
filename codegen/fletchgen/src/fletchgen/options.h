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

#include <vector>
#include <string>

#include "./logging.h"

std::string GetProgramName(char* argv0);

struct Options {
  std::vector<std::string> schemas;
  std::string output_dir;
  std::string srec_out;
  std::string srec_sim_dump;
  std::vector<std::string> recordbatches;
  std::vector<std::string> languages = {"vhdl"};
  std::string kernel_name = "kernel";
  bool axi_top = false;
  bool sim_top = false;
  bool quiet = false;
  bool verbose = false;

  /**
   * @brief Parse command line options and store the result
   * @param options A pointer to the Options object to parse into
   * @param argc    Argument count
   * @param argv    Argument values
   * @return        0 if successful, something else otherwise.
   */
  static int Parse(Options *options, int argc, char **argv);

  bool MustGenerateSREC();

  bool MustGenerateVHDL();
  bool MustGenerateDOT();

};