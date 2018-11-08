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
#include <sstream>
#include <memory>
#include <fstream>

#include <boost/program_options.hpp>

#include <arrow/api.h>
#include <arrow/ipc/api.h>
#include <arrow/io/api.h>

#include "arrow-meta.h"
#include "column.h"
#include "column-wrapper.h"

#include "srec/recordbatch.h"
#include "vhdt/vhdt.h"

#include "top/axi.h"
#include "top/sim.h"

#include "fletcher/common/arrow-utils.h"

using fletchgen::Mode;

/**
 * @mainpage Fletchgen documentation
 *
 * @section Introduction
 *
 * Fletchgen is Fletcher's wrapper generation tool. The tool will take an Apache Arrow Schema, and convert it into a
 * hardware description that wraps a bunch of ColumnReaders/Writers and generates an instantiation template for a
 * hardware accelerator function operating on Arrow data.
 *
 * @section Components
 * Fletchgen consists of a bunch of components.
 * <pre>
 * vhdl/ : Generic VHDL generation functionality
 * vhdt/ : VHDL template support
 * top/  : Support for various top-levels / platforms
 * srec/ : SREC generation for simulation purposes
 * </pre>
 *
 */

/// @brief Fletchgen main
int main(int argc, char **argv) {
  std::vector<std::shared_ptr<arrow::Schema>> schemas;
  std::shared_ptr<arrow::RecordBatch> rb;

  std::vector<std::string> schema_fnames;
  std::string output_fname;
  std::string acc_name;
  std::string wrap_name;

  /* Parse command-line options: */
  namespace po = boost::program_options;
  po::options_description desc("Options");

  desc.add_options()
      ("help,h", "Produce this help message")
      ("input,i",
       po::value<std::string>(),
       "Flatbuffer files with Arrow schemas to base wrapper on, comma seperated. E.g. file1.fbs,file2.fbs,...")
      ("output,o", po::value<std::string>(), "Wrapper output file.")
      ("name,n",
       po::value<std::string>()->default_value("<first input file name>"),
       "Name of the accelerator component.")
      ("wrapper_name,w", po::value<std::string>()->default_value("fletcher_wrapper"), "Name of the wrapper component.")
      ("recordbatch_data,d", po::value<std::string>(), "RecordBatch data input file name for SREC generation.")
      ("recordbatch_schema,s", po::value<std::string>(), "RecordBatch schema input file name for SREC generation.")
      ("axi", po::value<std::string>(), "AXI top level template file output")
      ("sim", po::value<std::string>(), "Simulation top level template file output")
      ("srec_output,x", po::value<std::string>(),
       "SREC output file name. If this and recordbatch_in are specified, this tool will convert an Arrow RecordBatch "
       "message stored in a file into an SREC file. The SREC file can be used in the simulation top-level.")
      ("srec_dump,y", po::value<std::string>(),
          "SREC file name to be filled in in simulation top level. All writes to memory are dumped in this SREC file"
          "during simulation.")
      ("quiet,q", "Prevent output on stdout.");

  /* Positional options: */
  po::positional_options_description p;
  p.add("input", -1);

  po::variables_map vm;

  /* Parse command line options with Boost */
  try {
    po::store(po::command_line_parser(argc, argv).options(desc).positional(p).run(), vm);
    po::notify(vm);
  } catch (const po::unknown_option &e) {
    std::cerr << "Unkown option: " << e.get_option_name() << std::endl;
    desc.print(std::cerr);
    return 0;
  }

  /* Option processing: */
  // Help:
  if (vm.count("help")) {
    desc.print(std::cout);
    return 0;
  }

  // Optional RecordBatch <-> SREC conversion
  std::string sro_fname;
  std::string srd_fname;
  std::vector<uint64_t> sro_buffers;

  auto cnt = vm.count("recordbatch_data") + vm.count("recordbatch_schema") + vm.count("srec_output");
  if ((cnt > 1) && (cnt < 3)) {
    std::cout << "Options recordbatch_data, recordbatch_schema and srec_output must all be set. Exiting."
              << std::endl;
    desc.print(std::cout);
    return 0;
  }
  if (vm.count("recordbatch_data")) {
    auto rbd_fname = vm["recordbatch_data"].as<std::string>();
    if (vm.count("recordbatch_schema")) {
      auto rbs_fname = vm["recordbatch_schema"].as<std::string>();
      if (vm.count("srec_output")) {
        sro_fname = vm["srec_output"].as<std::string>();
        auto rbs = fletcher::readSchemasFromFiles({rbs_fname});
        auto rbd = fletcher::readRecordBatchFromFile(rbd_fname, rbs[0]);
        sro_buffers = fletchgen::srec::writeRecordBatchToSREC(rbd.get(), sro_fname);
      }
    }
  }

  if (vm.count("srec_dump")) {
    srd_fname = vm["srec_dump"].as<std::string>();
  }

  // Schema inputs:
  if (vm.count("input")) {
    // Split argument into vector of strings
    auto schema_fnames_str = vm["input"].as<std::string>();
    schema_fnames = fletchgen::split(schema_fnames_str);
    schemas = fletcher::readSchemasFromFiles(schema_fnames);
  } else {
    std::cout << "No valid input file specified. Exiting..." << std::endl;
    desc.print(std::cout);
    return 0;
  }

  // Get initial configurations from schemas
  auto cfgs = fletchgen::config::fromSchemas(schemas);

  // VHDL output:
  if (vm.count("output")) {
    output_fname = vm["output"].as<std::string>();
  }

  // UserCore name:
  if (vm["name"].as<std::string>() != "<first input file name>") {
    acc_name = vm["name"].as<std::string>();
  } else {
    size_t lastindex = schema_fnames[0].find_last_of('.');
    acc_name = schema_fnames[0].substr(0, lastindex);
  }

  // Wrapper name:
  if (vm.count("wrapper_name")) {
    wrap_name = vm["wrapper_name"].as<std::string>();
  } else {
    wrap_name = nameFrom({"fletcher", "wrapper"});
  }

  std::vector<std::ostream *> outputs;

  /* Determine output streams */
  if (vm.count("quiet") == 0) {
    outputs.push_back(&std::cout);
  }

  std::ofstream ofs;
  /* Generate wrapper: */
  if (!output_fname.empty()) {
    ofs.open(output_fname);
    outputs.push_back(&ofs);
  }

  auto wrapper = fletchgen::generateColumnWrapper(outputs, schemas, acc_name, wrap_name, cfgs);
  LOGD("Wrapper generation finished.");

  /* AXI top level */
  if (vm.count("axi")) {
    LOGD("Generating AXI top level.");
    auto axi_file = vm["axi"].as<std::string>();
    std::ofstream aofs(axi_file);
    std::vector<std::ostream *> axi_outputs = {&aofs};
    if (vm.count("quiet") == 0) {
      axi_outputs.push_back(&std::cout);
    }
    top::generateAXITop(wrapper, axi_outputs);
  }

  /* Simulation top level */
  if (vm.count("sim")) {
    LOGD("Generating simulation top level.");
    auto simtop_file = vm["sim"].as<std::string>();
    std::ofstream stofs(simtop_file);
    std::vector<std::ostream *> simtop_outputs = {&stofs};
    if (vm.count("quiet") == 0) {
      simtop_outputs.push_back(&std::cout);
    }
    top::generateSimTop(wrapper, simtop_outputs, sro_fname, sro_buffers, srd_fname);
  }

  LOGD("Done.");

  return EXIT_SUCCESS;
}

