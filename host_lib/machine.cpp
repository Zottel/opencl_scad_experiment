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

#include "machine.hpp"

#include "util.hpp"

namespace scad {


machine::machine(cl::Platform platform, cl::Device device, std::string prog_filename)
	:platform(platform), device(device), prog_filename(prog_filename),
	 context{(std::vector<cl::Device>){device}, NULL, NULL, NULL, NULL}
{
	
	std::string platform_name = cl_info<std::string>(platform, CL_PLATFORM_NAME);;
	if(platform_name != "Intel(R) FPGA SDK for OpenCL(TM)" && platform_name != "Altera SDK for OpenCL") {
		throw std::domain_error("Platform not supported: " + platform_name);
	}
	
	std::vector<unsigned char> program_binary;
	readFile(prog_filename, program_binary);
	
	std::vector<std::pair<const void *,::size_t>> binaries{std::pair<const void *, ::size_t>{&(program_binary[0]), program_binary.size()}};
	cl::Program program{context, std::vector<cl::Device>{device}, binaries, NULL, NULL};
	
	std::vector<cl::Kernel> kernels;
	program.createKernels(&kernels);
	for(cl::Kernel kernel: kernels) {
		auto kernel_name = cl_info<std::string>(kernel, CL_KERNEL_FUNCTION_NAME);
		std::cout << "machine: kernel with name: " << kernel_name << std::endl;
		this->kernels[kernel_name] = kernel;
	}
	
}

bool machine::has_component(std::string kernel_name) {
	return kernels.count(kernel_name) > 0;
}

std::shared_ptr<machine::component> machine::get_component(std::string kernel_name) {
	cl::Kernel kern = kernels[kernel_name];
	
	if(existing_components.count(kernel_name) == 0) {
		existing_components[kernel_name] = std::shared_ptr<component>(new component(*this, kernel_name, kern));
	}
	
	return existing_components[kernel_name];
}

cl::Buffer machine::buffer(cl_mem_flags flags, size_t size) {
	return cl::Buffer(context, flags, size);
}

cl::Buffer machine::buffer(size_t size) { return buffer(CL_MEM_READ_WRITE, size); }


cl::size_t<3> machine::component::workgroup_dims() {
	//kernel.getWorkGroupInfo(machine.device, CL_KERNEL_COMPILE_WORK_GROUP_SIZE, sizeof(size_t[3]	), result.data());
	//kernel.getWorkGroupInfo(machine.device, CL_KERNEL_COMPILE_WORK_GROUP_SIZE, result.data());
	// WORKING:
	//cl::size_t<3> wgs = kernel.getWorkGroupInfo<CL_KERNEL_COMPILE_WORK_GROUP_SIZE>(machine.device);
	return kernel.getWorkGroupInfo<CL_KERNEL_COMPILE_WORK_GROUP_SIZE>(machine.device);
	
	//kernel.getWorkGroupInfo(machine.device, CL_KERNEL_COMPILE_WORK_GROUP_SIZE, res);
	//return result;
}

machine::component::component(scad::machine &machine, std::string name, cl::Kernel kernel)
	:machine(machine), kernel_name(name), kernel(kernel),
	 cmd_queue{machine.context, machine.device, 0, NULL}
{
}

std::string machine::component::name() {
	return kernel_name;
}

void machine::component::wait() {
	cmd_queue.flush();
	cmd_queue.finish();
}


} // namespace
