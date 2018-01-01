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

#ifndef SCAD_MACHINE_HPP 
#define SCAD_MACHINE_HPP 

#include<map>
#include<string>
#include<vector>
#include<memory>
#include<iostream>


#define CL_USE_DEPRECATED_OPENCL_1_2_APIS
#define __CL_ENABLE_EXCEPTIONS
#include <CL/cl.hpp>

#include "aligned_mem.hpp"

namespace scad {

class machine {
	cl::Platform platform;
	cl::Device device;
	std::string prog_filename;
	cl::Context context;
	std::map<std::string, cl::Kernel> kernels;
	
	
	public:
		class component {
			friend scad::machine; // parent class may use this as needed
			
			scad::machine &machine;
			std::string kernel_name;
			cl::Kernel kernel;
			cl::CommandQueue cmd_queue;
			
			component(scad::machine &machine, std::string name, cl::Kernel kernel);
			
			// recursive variadic template for arguments, called from start().
			// See http://en.cppreference.com/w/cpp/language/parameter_pack for info.
			template<typename... Targs>
			void args(int num, cl_uint p, Targs... Fargs) {
				kernel.setArg(num, sizeof(p), &p);
				args(num + 1, Fargs...);
			}
			template<typename... Targs>
			void args(int num, cl_ulong p, Targs... Fargs) {
				kernel.setArg(num, sizeof(p), &p);
				args(num + 1, Fargs...);
			}
			template<typename... Targs>
			void args(int num, cl::Buffer buff, Targs... Fargs) {
				kernel.setArg(num, buff);
				args(num + 1, Fargs...);
			}
			// Terminal case
			void args(int num) {}
			
			public:
				component(const component& that) = delete;
				std::string name();
				
				cl::size_t<3> workgroup_dims();
				
				template<typename... Targs>
				void start(Targs... Fargs) {
					// Set given arguments starting at offset 0
					args(0, Fargs...);
					auto dims = workgroup_dims();
					std::cout << "Starting kernel with work group dimensions: "
					          << dims[0] << ", "
					          << dims[1] << ", "
					          << dims[2] << std::endl;
					// Start kernel
					size_t work_items = dims[0] * dims[1] * dims[2];
					if(work_items > 0) {
						cmd_queue.enqueueNDRangeKernel(kernel,
						                               cl::NullRange,
						                               cl::NDRange(work_items),
						                               cl::NDRange(work_items));
					} else {
						cmd_queue.enqueueTask(kernel, NULL, NULL);
					}
				}
				
				template<typename vect_T>
				void write_buffer(cl::Buffer buff, std::vector<vect_T> &param) {
					size_t content_size = sizeof(vect_T) * param.size();
					// TODO: Blocking write for now
					cmd_queue.enqueueWriteBuffer(buff,CL_TRUE,0,content_size, param.data());
				}
				
				template<typename vect_T>
				void write_buffer(cl::Buffer buff, std::vector<vect_T, AlignedAllocator<vect_T>> &param) {
					size_t content_size = sizeof(vect_T) * param.size();
					// TODO: Blocking write for now
					cmd_queue.enqueueWriteBuffer(buff,CL_TRUE,0,content_size, param.data());
				}
				
				template<typename vect_T>
				void read_buffer(cl::Buffer buff, std::vector<vect_T> &param) {
					size_t content_size = sizeof(vect_T) * param.size();
					// TODO: Blocking read for now
					cmd_queue.enqueueReadBuffer(buff,CL_TRUE,0,content_size, param.data());
				}
				
				template<typename vect_T>
				void read_buffer(cl::Buffer buff, std::vector<vect_T, AlignedAllocator<vect_T>> &param) {
					size_t content_size = sizeof(vect_T) * param.size();
					// TODO: Blocking read for now
					cmd_queue.enqueueReadBuffer(buff,CL_TRUE,0,content_size, param.data());
				}
				
				
				void wait();
		};
	
	private:
	// runnung instance of kernels
		std::map<std::string, std::shared_ptr<component>> existing_components;
	
	
	public:
		// Deny copy constructor
		machine(const machine& that) = delete;
		
		machine(cl::Platform platform, cl::Device device, std::string prog_filename);
		
		bool has_component(std::string kernel_name);
		std::shared_ptr<component> get_component(std::string kernel_name);
		
		cl::Buffer buffer(cl_mem_flags flags, size_t size);
		
		cl::Buffer buffer(size_t size);
		
		// CL_MEM_READ_WRITE
		//   This flag specifies that the memory object will be read and written by a kernel. This is the default.
		// CL_MEM_WRITE_ONLY
		//   This flags specifies that the memory object will be written but not read by a kernel.
		//   Reading from a buffer or image object created with CL_MEM_WRITE_ONLY inside a kernel is undefined.
		// CL_MEM_READ_ONLY	
		//   This flag specifies that the memory object is a read-only memory object when used inside a kernel.
		//   Writing to a buffer or image object created with CL_MEM_READ_ONLY inside a kernel is undefined.
		//	
		template<typename vect_T>
		cl::Buffer buffer_for(cl_mem_flags flags, std::vector<vect_T, AlignedAllocator<vect_T>> param) {
			size_t content_size = sizeof(vect_T) * param.size();
			return buffer(flags, content_size);
		}
		
		template<typename vect_T>
		cl::Buffer buffer_for(std::vector<vect_T, AlignedAllocator<vect_T>> param) {
			return buffer_for(CL_MEM_READ_WRITE, param);
		}
		
};


} // namespace

#endif /* SCAD_MACHINE_HPP */

