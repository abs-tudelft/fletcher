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

#include "arrow-utils.h"
#include "column.h"
#include "column-wrapper.h"

#include "srec/recordbatch.h"
#include "vhdt/vhdt.h"

#include <plasma/client.h>

using fletchgen::Mode;

std::shared_ptr<arrow::Schema> getStringSchema() {
  // Schema
  auto schema = arrow::schema({arrow::field("Name", arrow::utf8(), false)});
  return schema;
}

std::shared_ptr<arrow::RecordBatch> getStringRB() {
  // Some names
  std::vector<std::string> names = {"Alice", "Bob", "Carol", "David",
                                    "Eve", "Frank", "Grace", "Harry",
                                    "Isolde", "Jack", "Karen", "Leonard",
                                    "Mary", "Nick", "Olivia", "Peter",
                                    "Quinn", "Robert", "Sarah", "Travis",
                                    "Uma", "Victor", "Wendy", "Xavier",
                                    "Yasmine", "Zachary"
  };

  // Make a string builder
  arrow::StringBuilder string_builder;

  // Append the strings in the string builder
  if (!string_builder.AppendValues(names).ok()) {
    throw std::runtime_error("Could not append strings to string builder.");
  };

  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> data_array;

  // Finish building and create a new data array around the data
  if (!string_builder.Finish(&data_array).ok()) {
    throw std::runtime_error("Could not finalize string builder.");
  };

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(getStringSchema(), names.size(), {data_array});

  return record_batch;
}

/**
 * @return Simplest example schema.
 */
std::shared_ptr<arrow::Schema> genSimpleReadSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Num", arrow::uint8(), false)
  };

  // Create the schema
  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(Mode::READ));

  return schema;
}

/**
 * @return Simple example schema with both read and write.
 */
std::shared_ptr<arrow::Schema> genSimpleWriteSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Num", arrow::uint8(), false)
  };

  // Create the schema
  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletchgen::metaMode(Mode::WRITE));

  return schema;
}

/**
 * @return A simple example schema.
 */
std::shared_ptr<arrow::Schema> genStringSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Name", arrow::utf8(), false, fletchgen::metaEPC(4))
  };

  // Create the schema
  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletchgen::metaMode(Mode::READ));

  return schema;
}

/**
 * @return A struct schema.
 */
std::shared_ptr<arrow::Schema> genStructSchema() {
  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("Prim A", arrow::uint16(), false),
      arrow::field("Prim B", arrow::uint32(), false),
  };

  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Struct", arrow::struct_(struct_fields), false)
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletchgen::metaMode(Mode::READ));

  return schema;

}

/**
 * @return A big example schema containing all field types that Fletcher supports.
 */
std::shared_ptr<arrow::Schema> genBigSchema() {
  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("Prim A", arrow::uint16(), false),
      arrow::field("Prim B", arrow::uint32(), false),
      arrow::field("String", arrow::utf8(), false, fletchgen::metaEPC(4))
  };

  std::vector<std::shared_ptr<arrow::Field>> struct2_fields = {
      arrow::field("Prim", arrow::uint64(), false),
      arrow::field("Struct", arrow::struct_(struct_fields), false)
  };

  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Prim", arrow::uint8(), false, fletchgen::metaEPC(4)),
      arrow::field("ListOfFloat", arrow::list(arrow::float64()), false),
      arrow::field("Binary", arrow::binary(), false),
      arrow::field("FixedSizeBinary", arrow::fixed_size_binary(5)),
      arrow::field("Decimal", arrow::decimal(20, 18)),
      arrow::field("String", arrow::utf8(), false, fletchgen::metaEPC(8)),
      arrow::field("Struct", arrow::struct_(struct2_fields), false),
      arrow::field("IgnoreMe", arrow::utf8(), false, fletchgen::metaIgnore())
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletchgen::metaMode(Mode::READ));

  return schema;
}

/**
 * @return An example schema from a genomics pipeline application.
 */
std::shared_ptr<arrow::Schema> genPairHMMSchema() {

  // Create the struct datatype
  auto strct = arrow::struct_({arrow::field("Basepairs", arrow::uint8(), false),
                               arrow::field("Probabilities", arrow::fixed_size_binary(32), false)
                              });
  // Create the schema fields vector
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Haplotype", arrow::binary(), false),
      arrow::field("Read", arrow::list(arrow::field("Item", strct, false)), false)
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletchgen::metaMode(Mode::READ));

  return schema;
}

int main(int argc, char **argv) {
  // TODO: Move this stuff to tests
  //auto schema = genStructSchema();
  //auto schema = genBigSchema();
  //auto schema = genPairHMMSchema();
  //auto schema = genSimpleReadSchema();
  auto schema = genStringSchema();
  fletchgen::writeSchemaToFile(schema, "test.fbs");
  auto rb = getStringRB();
  fletchgen::srec::writeRecordBatchToFile(*rb, "test.rb");

  std::string schema_fname;
  std::string output_fname;
  std::string acc_name;
  std::string wrap_name;
  int regs = 0;

  /* Parse command-line options: */
  namespace po = boost::program_options;
  po::options_description desc("Options");

  desc.add_options()
      ("help,h", "Produce this help message")
      ("input,I", po::value<std::string>(), "Flatbuffer file with Arrow schema to base wrapper on.")
      ("output,O", po::value<std::string>(), "Wrapper output file.")
      ("name,N", po::value<std::string>()->default_value("<input filename>"), "Name of the accelerator component.")
      ("wrapper_name,W", po::value<std::string>(), "Name of the wrapper component (Default = fletcher_wrapper).")
      ("custom_registers,R", po::value<int>(), "Number 32-bit registers in accelerator component.")
      ("recordbatch_data,D", po::value<std::string>(), "RecordBatch data input file name for SREC generation.")
      ("recordbatch_schema,S", po::value<std::string>(), "RecordBatch schema input file name for SREC generation.")
      ("srec_output,X", po::value<std::string>(),
         "SREC output file name. If this and recordbatch_in are specified, this "
         "tool will convert an Arrow RecordBatch message stored in a file into an"
         "SREC file. The SREC file can be used in simulation.")
      ("quiet,Q", "Prevent output on stdout.")
      ("axi,A", "Generate AXI top level.");

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
        auto sro_fname = vm["srec_output"].as<std::string>();
        auto rbs = fletchgen::readSchemaFromFile(rbs_fname);
        auto rbd = fletchgen::srec::readRecordBatchFromFile(rbd_fname, rbs);
        fletchgen::srec::writeRecordBatchToSREC(rbd.get(), sro_fname);
      }
    }
  }
  // Schema input:
  if (vm.count("input")) {
    schema_fname = vm["input"].as<std::string>();
  } else {
    std::cout << "No valid input file specified. Exiting..." << std::endl;
    desc.print(std::cout);
    return 0;
  }

  // VHDL output:
  if (vm.count("output")) {
    output_fname = vm["output"].as<std::string>();
  }

  // UserCore name:
  if (vm["name"].as<std::string>() != "<input filename>") {
    acc_name = vm["name"].as<std::string>();
  } else {
    size_t lastindex = schema_fname.find_last_of('.');
    acc_name = schema_fname.substr(0, lastindex);
  }

  // Wrapper name:
  if (vm.count("wrapper_name")) {
    wrap_name = vm["wrapper_name"].as<std::string>();
  } else {
    wrap_name = nameFrom({"fletcher", "wrapper"});
  }

  // UserCore registers:
  if (vm.count("custom_registers")) {
    regs = vm["custom_registers"].as<int>();
  }

  std::vector<std::ostream *> outputs;

  /* Determine output streams */
  if (vm.count("quiet") == 0) {
    outputs.push_back(&std::cout);
  }

  std::ofstream ofs;
  /* Generate wrapper: */
  if (!output_fname.empty()) {
    ofs = std::ofstream(output_fname);
    outputs.push_back(&ofs);
  }

  auto wrapper = fletchgen::generateColumnWrapper(outputs, fletchgen::readSchemaFromFile(schema_fname), acc_name, wrap_name, regs);
  LOGD("Wrapper generation finished.");

  /* AXI top level */
  if (vm.count("axi")) {
    const char* fhwd = std::getenv("FLETCHER_HARDWARE_DIR");
    if (fhwd == nullptr) {
      throw std::runtime_error("Environment variable FLETCHER_HARDWARE_DIR not set. Please source env.sh.");
    }
    fletchgen::vhdt t(std::string(fhwd) + "/vhdl/axi/axi_top.vhdt");

    t.replace("NUM_ARROW_BUFFERS", wrapper->countBuffers());
    t.replace("NUM_REGS", wrapper->countRegisters());
    t.replace("NUM_USER_REGS", wrapper->user_regs());

    // Do not change this order, TODO: fix this in replacement code
    t.replace("FLETCHER_WRAPPER_NAME", wrapper->entity()->name());
    t.replace("FLETCHER_WRAPPER_INST_NAME", nameFrom({wrapper->entity()->name(), "inst"}));

    std::ofstream aofs("axi_top.vhd");
    aofs << t.toString();
    aofs.close();

  }

  return 0;
}

