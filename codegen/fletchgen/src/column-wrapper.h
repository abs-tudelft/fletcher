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

#include <memory>
#include <utility>
#include <iostream>

#include "./vhdl/vhdl.h"

#include "./column.h"
#include "arrow-meta.h"
#include "./usercore.h"
#include "./usercore-controller.h"
#include "./config.h"

using vhdl::Signal;

namespace fletchgen {

// Forward decls.
class UserCore;

/**
 * @brief A signal that is derived from a port.
 */
class SignalFromPort : public Signal, public DerivedFrom<Port> {
 public:
  SignalFromPort(std::string name, Value width, Port *port) : Signal(std::move(name), std::move(width)),
                                                              DerivedFrom(port) {}

  SignalFromPort(std::string name, Port *port) : Signal(std::move(name)), DerivedFrom(port) {}
};

/**
 * @brief Wraps Column(Reader/Writer)s
 */
class ColumnWrapper : public StreamComponent {
 public:
  explicit ColumnWrapper(std::vector<std::shared_ptr<arrow::Schema>> schemas,
                         std::string name,
                         std::string acc_name,
                         std::vector<config::Config> configs = {});

  /// @brief Return the schema this wrapper implementation is derived from.
  std::vector<std::shared_ptr<arrow::Schema>> schemas() { return schemas_; }

  /// @brief Return a human readable string with some info about this wrapper.
  std::string toString() override;

  /// @brief Return a human readable string with a lot of info about this wrapper.
  std::string toInfoString();

  /// @brief Return all the Column(Reader/Writer) instances of this wrapper.
  std::vector<std::shared_ptr<Column>> column_instances();

  UserCore *usercore() { return usercore_.get(); }

  UserCoreController *usercore_controller() { return uctrl_.get(); }

  /// @brief Count the number of Arrow buffers used by this wrapper.
  int countBuffers();

  /// @brief Count the number of MMIO registers used by this wrapper.
  int countRegisters();

  /// @brief Return the number of user registers.
  int user_regs() {
    int ret = 0;
    for (const auto &cfg : cfgs_) {
      ret += cfg.user.num_user_regs;
    }
    return ret;
  }

  /// @brief Return the configurations for each Schema
  std::vector<config::Config> configs() { return cfgs_; }

 private:
  std::vector<std::shared_ptr<arrow::Schema>>
      schemas_ = {};  ///< The schema this wrapper implementation is derived from.
  std::vector<config::Config> cfgs_;  ///< Configurations

  std::shared_ptr<UserCore> usercore_;  ///< UserCore component that has to be implemented by the user.
  std::shared_ptr<Instantiation> usercore_inst_;  ///< UserCore instance.

  std::shared_ptr<UserCoreController> uctrl_;  ///< UserCore controller component
  std::shared_ptr<Instantiation> uctrl_inst_;  ///< UserCore controller instance

  std::shared_ptr<ReadArbiter> rarb;  ///< Read Arbiter component.
  std::shared_ptr<Instantiation> rarb_inst;  ///< Read Arbiter instance.

  std::shared_ptr<WriteArbiter> warb;  ///< Write Arbiter component.
  std::shared_ptr<Instantiation> warb_inst;  ///< Write Arbiter instance.

  GeneralPort *regs_in();;

  GeneralPort *regs_out();;

  GeneralPort *regs_out_en();;

  int pgroup_ = 0;  ///< Current port group, useful when adding new port.
  int sgroup_ = 0;  ///< Current signal group, useful when adding new signals.

  /* Generics */
  /// @brief Add all generics to the wrapper entity.
  void addGenerics();

  /* Columns */
  /// @brief Return a vector with Column instantiations derived from a schema.
  std::vector<std::shared_ptr<Column>> createColumns();

  /// @brief Add Column instantiations to this wrapper.
  void addColumns(const std::vector<std::shared_ptr<Column>> &columns);

  /// @brief Return the number of Columns of mode \p mode
  int countColumnsOfMode(Mode mode);

  /// @brief Generate signals in this wrappers architecture.
  void addInternalColumnSignals();

  /* Streams */
  /// @brief Generate the wrapper streams for the user.
  void addUserStreams();

  /// @brief Return all Fletcher stream of a specific type on this wrapper.
  std::vector<FletcherStream *> getFletcherStreams(std::vector<std::shared_ptr<Stream>> streams);

  /* Arbiters */
  /// @brief generate the internal signals for the read arbiter.
  void addInternalReadArbiterSignals(std::vector<std::shared_ptr<StreamPort>> ports);

  /// @brief generate the internal signals for the write arbiter.
  void addInternalWriteArbiterSignals(std::vector<std::shared_ptr<StreamPort>> ports);

  /// @brief Add the read arbiter
  void addReadArbiter();

  /// @brief Add the write arbiter
  void addWriteArbiter();

  /// @brief Return the write arbiter instance if it exists, nullptr otherwise.
  std::shared_ptr<Instantiation> write_arbiter_inst();

  /// @brief Return the read arbiter instance if exists, nullptr otherwise.
  std::shared_ptr<Instantiation> read_arbiter_inst();

  /// @brief Return the read arbiter component
  ReadArbiter *read_arbiter() { return rarb.get(); }

  /// @brief Return the write arbiter component
  WriteArbiter *write_arbiter() { return warb.get(); }

  /* Ports */
  /// @brief Generate global ports for the wrapper, such as clk, reset, etc...
  void addGlobalPorts();

  /// @brief Add register ports.
  void addRegisterPorts();

  /* Connections */
  /// @brief Connect global ports of some instance
  void connectGlobalPortsOf(Instantiation *instance);

  /// @brief Generate the internal connections for this wrapper.
  void connectUserCoreStreams();

  /// @brief Connect an ArrowPort to a wrapper signal.
  void connectArrowPortToSignal(FletcherColumnStream *stream, Column *column, ArrowPort *port);

  /// @brief Connect a CommandPort to a wrapper signal.
  void connectCommandPortToSignal(FletcherColumnStream *stream, Column *column, CommandPort *port);

  /// @brief Connect read request channels to arbiter.
  void connectReadRequestChannels();

  /// @brief Connect read data channels to arbiter.
  void connectReadDataChannels();

  /// @brief Connect write request channels to arbiter.
  void connectWriteRequestChannels();

  /// @brief Connect write data channels to arbiter.
  void connectWriteDataChannels();

  /// @brief Connect global ports such as clock, reset, etc...
  void connectGlobalPorts();

  /// @brief Add internal signals for controller <-> user core
  void connectControllerSignals();

  /// @brief Add internal controller signals.
  void addControllerSignals();

  /// @brief Connect the controller registers to the wrapper ports.
  void connectControllerRegs();

  void implementUserRegs();

  void mapUserGenerics();

  // TODO(johanpel): implement validation of config compatibility amongst multiple schemas
  void validateConfigs() {};
};

}  // namespace fletchgen
