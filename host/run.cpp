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
#include <string>
#include <list>
#include <iostream>
#include <fstream>
#include <thread>
#include <chrono>


#define CL_USE_DEPRECATED_OPENCL_1_2_APIS
#define __CL_ENABLE_EXCEPTIONS
#include <CL/cl.hpp>

#include "util.hpp"
#include "machine.hpp"
#include "assembly.hpp"

#include "common/instructions.h"

using namespace scad;

void print_scad_vector(std::vector<scad_data, AlignedAllocator<scad_data>> data) {
	std::cout << std::hex << "[";
		bool first = true;
		for(auto const& value: data) {
			if(first) {
				first = false;
			} else {
				std::cout << ", ";
			}
			std::cout << value.integer;
		}
		std::cout << "]";
}


int main (int argc, char *argv[]) {
	// Have openCL kernels not buffer debug messages.
	setbuf(stdout, NULL);
	
	std::vector<std::string> args(argv+1, argv+argc);
	
	std::string description_filename = "", aocx_filename = "", assembly_filename = "";
	switch(args.size()) {
		case 3:
			description_filename = args[0];
			aocx_filename = args[1];
			assembly_filename = args[2];
			break;
		default:
			std::cerr << "usage: run <processor_description> <processor_aocx> <assembly program>"
			          << std::endl;
			exit(1);
	}
	
	// Processor description is used by assembler to map unit names to addresses.
	processor_description proc(description_filename);
	
	// Read assembly program into string.
	std::ifstream assembly_stream(assembly_filename);
	std::string assembly_src((std::istreambuf_iterator<char>(assembly_stream)),
	                         std::istreambuf_iterator<char>());
	
	// Parse and link assembly source into vector of scad instructions.
	scad::assembly assembly(proc);
	assembly.parse(assembly_src);
	std::vector<struct scad_instruction> prog_unaligned = assembly.build();
	// Align program for transfer to buffer.
	std::vector<struct scad_instruction, AlignedAllocator<struct scad_instruction>>
		prog;
	// Copy unaligned to aligned memory.
	std::copy(prog_unaligned.begin(), prog_unaligned.end(),
		std::back_inserter(prog));
	
	
	
	// Only run on FPGA platform.
	#if AOC_VERSION == 17
		cl::Platform platform = cl_find_platform("Intel(R) FPGA SDK for OpenCL(TM)");
	#else
		cl::Platform platform = cl_find_platform("Altera SDK for OpenCL");
	#endif
	
	std::vector<cl::Device> devices;
	platform.getDevices(CL_DEVICE_TYPE_ALL, &devices);
	
	scad::machine machine(platform, devices[0], aocx_filename);
	
	// TODO: Temporary workaround to get emulator to run workgroup.
	//       Normally, the interconnect should be an autorun kernel.
	if(machine.has_component("interconnect")) {
		machine.get_component("interconnect")->start();
	}
	
	// INPUT/OUTPUT MEMORY
	std::vector<scad_data, AlignedAllocator<scad_data>>
		data(256, (scad_data){.integer = 0});
	
	//for(size_t i = 0; i < data.size(); i++) data[i] = (scad_data){.integer = i};
	
	std::cout << "input: ";
	print_scad_vector(data); std::cout << std::endl;
	
	auto data_buff = machine.buffer_for(CL_MEM_READ_ONLY, data);
	auto lsu  = machine.get_component("lsu");
	lsu->write_buffer(data_buff, data);
	std::cout << "starting data buffer transfer" << std::endl;
	lsu->start(data_buff, (cl_uint) data.size());
	std::cout << "starting lsu" << std::endl;
	
	// Finally - execute our program.
	auto control   = machine.get_component("cu");
	auto prog_buff = machine.buffer_for(prog);
	std::cout << "starting program buffer transfer" << std::endl;
	control->write_buffer(prog_buff, prog);
	std::cout << "control unit: start" << std::endl;
	control->start(prog_buff, (cl_uint) prog.size());
	
	std::cout << "starting data transfer back" << std::endl;
	lsu->read_buffer(data_buff, data);
	std::cout << "data transfer back done" << std::endl;
	
	lsu->wait();
	std::cout << "lsu unit: wait" << std::endl;
	
	// Print output to stdout.
	// TODO: write to file.
	std::cout << "output: "; print_scad_vector(data); std::cout << std::endl;
	
	control->wait();
	std::cout << "control unit: done" << std::endl;

}

