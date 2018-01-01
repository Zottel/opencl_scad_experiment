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

#ifndef SCAD_UTIL_H
#define SCAD_UTIL_H

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <list>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <iterator>

#define CL_USE_DEPRECATED_OPENCL_1_2_APIS
#define __CL_ENABLE_EXCEPTIONS
#include <CL/cl.hpp>

std::string cl_info(cl::Platform on, cl_platform_info what);

size_t filesize(std::string filename);

template <typename T, typename onT, typename whatT>
T cl_info(onT on, whatT what) {
	T info;
	on.getInfo(what, &info);
	return info;
}

void readFile(std::string filename, std::vector<unsigned char> &buffer);

// adapted from https://stackoverflow.com/questions/15138353/reading-the-binary-file-into-the-vector-of-unsigned-chars
template<typename T>
void readVectorFile(std::string filename, std::vector<T> dest) {
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
	
	// file size dividable by sizeof(T)?
	if(fileSize % sizeof(T)) {
		throw std::ios_base::failure("Size of file \'"
		                             + filename + "\' is not a multiple of "
		                             + std::to_string(sizeof(T)) + ".");
	}
	// reserve capacity
	dest->reserve(fileSize / sizeof(T));
	
	// read the data:
	dest->insert(dest->begin(),
	             std::istream_iterator<T>(file),
	             std::istream_iterator<T>());
	
	return;
}

cl::Platform cl_find_platform(std::string name);

// Turns vector {"key0", "value0", "key1", "value1"} into map<string,string>
std::map<std::string, std::string> parse_opts(std::vector<std::string> opts,
                                              std::set<std::string> expected);

#endif /* SCAD_UTIL_H */
