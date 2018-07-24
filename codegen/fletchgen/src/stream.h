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
#include <arrow/type.h>
#include <netinet/in.h>
#include <deque>

#include "vhdl/vhdl.h"
#include "meta.h"

using vhdl::Component;
using vhdl::Value;
using vhdl::Port;
using vhdl::Dir;
using vhdl::Signal;

namespace fletchgen {

class Stream;

/**
 * @brief A port that is part of a stream.
 */
class StreamPort : public Port, public ChildOf<Stream> {
 public:
  StreamPort(const std::string &name, Dir dir, Value width, Stream *stream) :
      Port(name, dir, std::move(width)), ChildOf(stream) {}

  StreamPort(const std::string &name, Dir dir, Stream *stream) :
      Port(name, dir), ChildOf(stream) {}
};

/**
 * @brief An offset.
 */
class WithOffset {
 public:
  WithOffset() = default;

  explicit WithOffset(Value offset) : offset_(std::move(offset)) {};

  void setOffset(Value offset) { offset_ = std::move(offset); }

  Value offset() { return offset_; }

 private:
  Value offset_ = Value(0);
};

/**
 * @brief A hardware stream.
 */
class Stream {
 public:
  ///@brief Construct a stream, optionally from ports.
  explicit Stream(std::string name, std::vector<std::shared_ptr<StreamPort>> ports = {});

  /// @brief Add \p port to this stream.
  void addPort(const std::shared_ptr<StreamPort> &port);

  /// @brief Add \p ports to this stream.
  void addPort(std::vector<std::shared_ptr<StreamPort>> ports);

  /// @brief Invert the directions of the ports on this stream.
  Stream *invert();

  /// @brief Return a vector with pointers to the port of this stream.
  std::vector<std::shared_ptr<StreamPort>> ports();

  /// @brief Return the name of this stream.
  const std::string name() { return name_; }

  /// @brief Set the group of all ports of this stream.
  Stream *setGroup(int group);

  virtual std::string toString() { return "[STREAM: " + name_ + " | ports: " + std::to_string(ports_.size()) + "]"; }

 private:
  std::string name_;
  std::vector<std::shared_ptr<StreamPort>> ports_;
};

/**
 * @brief A component containing streams on its interface.
 */
class StreamComponent : public Component {
 public:

  /**
   * @brief Construct a component that can contain streams.
   * @param name The name of the component.
   */
  explicit StreamComponent(std::string name) : Component(std::move(name)) {}

  /**
   * @brief Construct a component that contains the streams \p streams.
   * @param name The name of the component.
   * @param streams The streams to initialize the component with.
   */
  StreamComponent(std::string name, std::deque<std::shared_ptr<Stream>> streams)
      : Component(std::move(name)), _streams(std::move(streams)) {}

  std::deque<std::shared_ptr<Stream>> streams() { return _streams; }

  std::string toString() override;

  /**
   * @brief Generate ports on the entity from the streams.
   */
  void addStreamPorts(int *group = nullptr);

  /**
   * @brief Add a \p stream to this component.
   * @param stream
   */
  void appendStream(const std::shared_ptr<Stream> &stream) { _streams.push_back(stream); }

  void prependStream(const std::shared_ptr<Stream> &stream) { _streams.push_front(stream); }

 protected:
  std::deque<std::shared_ptr<Stream>> _streams;
};

/*
template<class T>
class TypedSignal: public Signal, public TypedBy<T> {
 public:
  TypedSignal(std::string name, Value width, bool is_vector, T type) : Signal(name, width, is_vector), TypedBy<T>(type) {}
};

template<class T>
class StreamSink;

template<class T>
class StreamSource {
 public:
 private:
  std::vector<std::shared_ptr<TypedSignal<T>>> signals_;
  StreamSink<T>* sink_;
};

template<class T>
class StreamSink {
 public:
 private:
  std::vector<std::shared_ptr<TypedSignal<T>>> signals_;
  StreamSource<T>* source_;
};

template<class T>
class ConcatenatedStreamSource {
 private:
  std::vector<std::shared_ptr<StreamSource<T>>> sources_;
  std::vector<StreamSource<T>*> sinks_;
};

template<class T>
class ConcatenatedStreamSink {
 private:
  std::vector<std::shared_ptr<StreamSource<T>>> sinks_;
  std::vector<StreamSource<T>*> sources_;
};

template<class T>
class StreamConnection {
 public:
  StreamConnection(StreamSource<T>* source, StreamSink<T>* sink) {

  }

  StreamConnection(ConcatenatedStreamSource<T>* source, StreamSink<T>* sink) {

  }

  StreamConnection(StreamSource<T>* source, ConcatenatedStreamSink<T>* sink) {

  }

 private:

};
*/

}//namespace fletchgen
