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

// Helpers for logging

#pragma once

#include <iomanip>

#ifdef USE_BOOST_LOG
#define BOOST_LOG_DYN_LINK 1
#include <boost/log/trivial.hpp>
#define LOGD(X) BOOST_LOG_TRIVIAL(debug) << X
#define LOGI(X) BOOST_LOG_TRIVIAL(info) << X
#define LOGE(X) BOOST_LOG_TRIVIAL(error) << X
#else
#include <iostream>
#ifdef DEBUG
#define LOGD(X) std::cout << "DEBUG: " << X << std::endl
#else
#define LOGD(X) do {} while (false)
#endif
#define LOGI(X) std::cout << "INFO : " << X << std::endl
#define LOGE(X) std::cerr << "ERROR: " << X << std::endl
#endif

#define STRHEX64 "0x" << std::hex << std::setfill('0') << std::setw(16)
#define STRHEX32 "0x" << std::hex << std::setfill('0') << std::setw( 8)
