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

#include <iostream>

#ifdef DEBUG
#define LOGD(X) std::cerr << "[DEBUG] " << (X) << std::endl
#else
#define LOGD(X) do {} while (false)
#endif

#define LOGI(X) std::cerr << "[INFO] : " << (X) << std::endl
#define LOGE(X) std::cerr << "[ERR ] : " << (X) << std::endl
#define LOGW(X) std::cerr << "[WARN] : " << (X) << std::endl