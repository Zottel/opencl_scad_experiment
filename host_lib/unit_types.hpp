//   Copyright 2018 Julius Roob <julius@juliusroob.de>
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.


#include <cstdio>
#include <cstdlib>
#include <vector>
#include <list>
#include <iostream>
#include <fstream>
#include <algorithm>
#include <iterator>
#include <regex>
#include <map>

#define CL_USE_DEPRECATED_OPENCL_1_2_APIS
#define __CL_ENABLE_EXCEPTIONS
#include <CL/cl.hpp>

namespace scad {


std::map<std::string, std::pair<std::map<std::string, int>, std::map<std::string, int>>> const unit_type_buffers {
	{"cu",
		{ { /* Input */ {"in0", 0}, {"in1", 1}, {"in2", 2} },
		  { /* Output */ } }
	},
	{"lsu",
		{ { /* Input */ {"in0", 0}, {"in1", 1}, {"opc", 2} },
		  { /* Output */ {"out", 0} } }
	},
	{"memory_stream_in",
		{ { /* Input */ {"in0", 0} },
		  { /* Output */ } }
	},
	{"memory_stream_out",
		{ { /* Input */ },
		  { /* Output */ {"out", 0} } }
	},
	{"rob",
		{ { /* Input */ {"in0", 0} },
		  { /* Output */ {"out", 0} } }
	},
	{"pu",
		{ { /* Input */ {"in0", 0}, {"in1", 1}, {"opc", 2} },
		  { /* Output */ {"out", 0} } }
	},
};

} // namespace scad
