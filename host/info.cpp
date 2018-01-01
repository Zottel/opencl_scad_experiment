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

#define CL_USE_DEPRECATED_OPENCL_1_2_APIS
#define __CL_ENABLE_EXCEPTIONS
#include <CL/cl.hpp>


template <typename T, typename onT, typename whatT>
void print_info(onT on, whatT what, std::string what_str)
{
	T info;
	on.getInfo(what, &info);
	std::cout << what_str << ": " << info << std::endl;
}

void print_devices(cl::Platform platform)
{
	std::vector<cl::Device> devices;
	
	cl_int result = platform.getDevices(CL_DEVICE_TYPE_ALL, &devices);
	std::cout << "getDevices returned: " << result << std::endl;
	
	for(auto device : devices) {
		print_info<std::string>(device, CL_DEVICE_NAME, "device: ");
		std::cout << "--------------------------" << std::endl;
		
		print_info<cl_bool>(device, CL_DEVICE_COMPILER_AVAILABLE, "compiler available");
		print_info<cl_uint>(device, CL_DEVICE_ADDRESS_BITS, "address bits");
		print_info<cl_bool>(device, CL_DEVICE_ENDIAN_LITTLE, "little endian");
		print_info<std::string>(device, CL_DEVICE_EXTENSIONS, "device extensions");
		
		print_info<cl_ulong>(device, CL_DEVICE_GLOBAL_MEM_SIZE, "global mem size");
		print_info<cl_ulong>(device, CL_DEVICE_LOCAL_MEM_SIZE, "local mem size");
		
		print_info<cl_uint>(device, CL_DEVICE_MAX_CLOCK_FREQUENCY, "max clock freq");
		print_info<cl_uint>(device, CL_DEVICE_MAX_COMPUTE_UNITS, "max compute units");
		print_info<cl_uint>(device, CL_DEVICE_MAX_CONSTANT_ARGS, "max constant args");
		print_info<cl_ulong>(device, CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE	,
		                     "max constant buffer size");
		print_info<cl_ulong>(device, CL_DEVICE_MAX_MEM_ALLOC_SIZE,
		                     "max mem alloc size");
		print_info<size_t>(device, CL_DEVICE_MAX_PARAMETER_SIZE, "max parameter size");
		print_info<size_t>(device, CL_DEVICE_MAX_WORK_GROUP_SIZE,
		                   "max work group size");
		print_info<cl_uint>(device, CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS,
		                    "max work item dimensions");
		
		print_info<std::string>(device, CL_DEVICE_PROFILE, "device profile");
		
		
		print_info<cl_uint>(device, CL_DEVICE_MEM_BASE_ADDR_ALIGN,
		                    "mem base addr align");
		
		print_info<std::string>(device, CL_DEVICE_VENDOR, "device vendor");
		print_info<std::string>(device, CL_DEVICE_VERSION, "device version");
		print_info<std::string>(device, CL_DRIVER_VERSION, "driver version");
		
		
		// See if context creation possible
		cl::Context context{(std::vector<cl::Device>){device}, NULL, NULL, NULL, NULL};
		std::cout << std::endl;
	}
}

void print_platforms()
{
	std::vector<cl::Platform> platforms;
	cl::Platform::get(&platforms);
	std::cout << std::endl;
	
	for(auto platform : platforms) {
		print_info<std::string>(platform, CL_PLATFORM_NAME, "platform name");
		std::cout << "##########################" << std::endl;
		print_info<std::string>(platform, CL_PLATFORM_PROFILE, "platform profile");
		print_info<std::string>(platform, CL_PLATFORM_VERSION, "platform version");
		print_info<std::string>(platform, CL_PLATFORM_VENDOR, "platform vendor");
		print_info<std::string>(platform, CL_PLATFORM_EXTENSIONS,
		                        "platform extensions");
		try {
			print_devices(platform);
		} catch(cl::Error err) {
			std::cerr << "DEVICE QUERY ERROR: " << err.what() << "(" << err.err() << ")" << std::endl;
		}
		std::cout << std::endl;
	}
}

int main(int argc, char *argv[])
{
	std::vector<std::string> args(argv + 1, argv + argc);
	
	cl_int err = CL_SUCCESS;
	try {
		print_platforms();
	} catch(cl::Error err) {
		std::cerr << "ERROR: " << err.what() << "(" << err.err() << ")" << std::endl;
	}
	
	return EXIT_SUCCESS;
}

