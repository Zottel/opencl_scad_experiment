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

#include "util.hpp"

#include "common/instructions.h"

#include "description.hpp"
#include "assembly.hpp"

using namespace scad;

std::vector<struct scad_instruction> assemble(processor_description proc, std::string text) {
	scad::assembly a(proc);
	a.parse(text);
	return a.build();
}

int main (int argc, char *argv[]) {
	std::vector<std::string> args(argv+1, argv+argc);
	if(args.size() != 2) {
		std::cerr << "usage: assembler <platform_description> <assembly file>" << std::endl
		          << std::endl
		          << "This tool is meant to test the assembly library." << std::endl
		          << "Assembly is meant to be done by the 'run' tool." << std::endl;
		exit(1);
	}
	
	processor_description proc(args[0]);
	
	std::ifstream fstr(args[1]);
	std::string prog_str((std::istreambuf_iterator<char>(fstr)),
	                     std::istreambuf_iterator<char>());
	//std::cout << prog_str << std::endl;;
	
	auto prog = assemble(proc, prog_str);
	
	for(struct scad_instruction instr: prog) {
		switch(instr.op) {
			case SCAD_MOVE:
				std::cout << "move "
				          << (int)instr.from.unit << "@" << (int)instr.from.buffer
				          << " -> "
				          << (int)instr.to.unit << "@" << (int)instr.to.buffer
				          << std::endl;
				break;
			case SCAD_MOVE_IMMEDIATE:
				std::cout << "move_immediate"
				          << " $" << instr.immediate.integer
				          << " or float $" << instr.immediate.floating_point
				          << " or $(" << instr.immediate.op.opcode << ", " << instr.immediate.op.count << ")"
				          << " -> "
				          << (int)instr.to.unit << "@" << (int)instr.to.buffer
				          << std::endl;
				break;
			case SCAD_MOVE_PC:
				std::cout << "move_pc "
				          << (int)instr.from.unit << "@" << (int)instr.from.buffer
				          << " -> "
				          << "pc"
				          << std::endl;
				break;
			default:
				std::cout << "invalid opcode: " << instr.op << std::endl;
		}
	}
	return EXIT_SUCCESS;
}
