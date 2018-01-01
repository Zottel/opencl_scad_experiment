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

#include "common/instructions.h"
#include "unit_types.hpp"
#include "description.hpp"

namespace scad {

class assembly_exception : public std::runtime_error {
	public: using runtime_error::runtime_error;
};

class assembly {
	processor_description proc;
	
	std::map <std::string, struct scad_buffer_address> input_buffers = {};
	std::map <std::string, struct scad_buffer_address> ouput_buffers = {};
	
	std::map<std::string, enum scad_lsu_opcode> lsu_op_strings = {
		{"st", SCAD_LSU_STORE}, {"ld", SCAD_LSU_LOAD},
	};
	
	std::map<std::string, enum scad_pu_opcode> pu_op_strings = {
		{"addN", SCAD_PU_ADDN}, {"subN", SCAD_PU_SUBN}, {"mulN", SCAD_PU_MULN},
		{"divN", SCAD_PU_DIVN}, {"modN", SCAD_PU_MODN}, {"lesN", SCAD_PU_LESN},
		{"leqN", SCAD_PU_LEQN}, {"eqqN", SCAD_PU_EQQN}, {"neqN", SCAD_PU_NEQN},
		{"addZ", SCAD_PU_ADDZ}, {"subZ", SCAD_PU_SUBZ}, {"mulZ", SCAD_PU_MULZ},
		{"divZ", SCAD_PU_DIVZ}, {"modZ", SCAD_PU_MODZ}, {"lesZ", SCAD_PU_LESZ},
		{"leqZ", SCAD_PU_LEQZ}, {"eqqZ", SCAD_PU_EQQZ}, {"neqZ", SCAD_PU_NEQZ},
		{"andB", SCAD_PU_ANDB}, {"orB",  SCAD_PU_ORB}, {"eqqB", SCAD_PU_EQQB},
		{"neqB", SCAD_PU_NEQB},
	};
	
	std::vector<struct scad_instruction> result;
	// symbol to where
	std::map<std::string, int> symbol;
	// instructions that still require the localion of their symbols
	std::map<int, std::string> unlinked;
	
	void push_label(std::string label);
	std::pair<bool, scad_data> parse_immediate(std::string immediate_string);
	std::pair<bool, std::string> parse_label_from(std::string addr_str);
	std::pair<bool, struct scad_buffer_address> parse_address_from(std::string addr_str);
	std::pair<bool, struct scad_buffer_address> parse_address_to(std::string addr_str);
	void push_move(std::string from, std::string to);
	
	public:
		assembly(processor_description proc);
		
		std::vector<struct scad_instruction> build();
		
		void parse(std::string program_str);
};

} // namespace scad
