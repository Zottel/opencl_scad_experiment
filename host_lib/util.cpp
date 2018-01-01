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


#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <list>
#include <iostream>
#include <fstream>
#include <fstream>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <iterator>

#define CL_USE_DEPRECATED_OPENCL_1_2_APIS
#define __CL_ENABLE_EXCEPTIONS
#include <CL/cl.hpp>

#include "util.hpp"

// This is a workaround for the templated version in the header file.
// Some OpenCL APIs add a 0-byte to the returned string
std::string cl_info(cl::Platform on, cl_platform_info what) {
	std::string info;
	on.getInfo(what, &info);
	info.resize(strlen(info.c_str()));
	return info;
}

size_t filesize(std::string filename) {
	std::ifstream file(filename, std::ios::binary | std::ios::ate);
	return file.tellg();
}

// adapted from https://stackoverflow.com/questions/15138353/reading-the-binary-file-into-the-vector-of-unsigned-chars
void readFile(std::string filename, std::vector<unsigned char> &buffer)
{
	// open the file:
	std::ifstream file(filename, std::ios::binary);
	if(file.fail()) {
		throw std::ios_base::failure("Could not open " + filename);
	}

	// Stop eating new lines in binary mode!!!
	file.unsetf(std::ios::skipws);

	// get its size:
	std::streampos fileSize;

	file.seekg(0, std::ios::end);
	fileSize = file.tellg();
	file.seekg(0, std::ios::beg);

	// reserve capacity
	buffer.reserve(fileSize);

	// read the data:
	buffer.insert(buffer.begin(),
			std::istream_iterator<unsigned char>(file),
			std::istream_iterator<unsigned char>());

	return;
}

cl::Platform cl_find_platform(std::string name) {
	std::vector<cl::Platform> platforms;
	cl::Platform::get(&platforms);
	auto it = find_if(platforms.begin(), platforms.end(),
	                  [name](const cl::Platform& platform) {return cl_info<std::string>(platform, CL_PLATFORM_NAME) == name;});
	
	if (it == platforms.end()) {
		throw std::invalid_argument("No platform matching " + name + "found");
	} else {
		return *it;
	}
}

// Turns vector {"key0", "value0", "key1", "value1"} into map<string,string>
std::map<std::string, std::string> parse_opts(std::vector<std::string> opts,
                                              std::set<std::string> expected) {
	std::map<std::string, std::string> result;
	
	auto it = opts.begin();
	auto end = opts.end();
	
	while(it != end) {
		std::string key = *it;
		if(expected.find(key) == expected.end()) {
			throw std::runtime_error("Unexpected parameter: " + key);
		}
		
		if((it+1) != end) {
			std::string val = *(it + 1);
			result.insert(std::make_pair(key, val));
			std::cout << key << ": " << val << std::endl;
			it+=2;
		} else {
			throw std::runtime_error("Missing value after key: " + *it);
			//std::cerr << "Missing parameter after: " << *it << std::endl;
			//exit(1);
		}
	}
	
	return result;
}

