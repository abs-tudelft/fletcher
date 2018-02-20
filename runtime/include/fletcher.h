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

#include "fletcher/common.h"
#include "fletcher/FPGAPlatform.h"
#include "fletcher/logging.h"
#include "fletcher/UserCore.h"

#ifdef USE_AWS
#include "fletcher/aws/aws.h"
#endif

#ifdef USE_SNAP
#include "fletcher/snap/snap.h"
#endif

// The boilerplate code for FPGA platform implementation
#include "fletcher/echo/echo.h"

#define FLETCHER_OK 0
#define FLETCHER_ERROR -1
