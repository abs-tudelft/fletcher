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

#include <fletchgen/cli/CLI11.hpp>
#include <fletchgen/logging.h>
#include <fletchgen/options.h>

int main(int argc, char **argv) {
  // Start logging
  fletchgen::logging::StartLogging(argv[0], fletchgen::logging::LOG_DEBUG, std::string(argv[0]) + ".log");

  // Parse options
  auto options = std::make_unique<Options>();
  Options::Parse(options.get(), argc, argv);

  // Run generation
  // generation step goes here

  // Shut down logging
  fletchgen::logging::StopLogging();
  return 0;
}
