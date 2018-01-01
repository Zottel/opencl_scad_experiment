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

#ifndef SCAD_DESCRIPTION_H
#define SCAD_DESCRIPTION_H

#include <vector>
#include <string>
#include <list>
#include <map>

#include "pugixml.hpp"

#include "common/instructions.h"


namespace scad {

class description_exception : public std::runtime_error {
	public: using runtime_error::runtime_error;
};

class interconnect_description {
	public:
		std::string name;
		std::string implementation;
		int size;
		
		interconnect_description(std::string name, std::string implementation, int size)
			:name(name), implementation(implementation), size(size){}
};

class unit_description {
	public:
		std::string name;
		std::string type;
		std::string implementation;
		int number;
		
		std::map<std::string, struct scad_buffer_address> input_buffers;
		std::map<std::string, struct scad_buffer_address> output_buffers;
		
		std::map<std::string, std::string> parameters;
		
		unit_description(std::string name, std::string type, std::string implementation, int number, std::map<std::string, std::string> parameters);
};

class processor_description {
	public:
		std::string name;
		
		int buffer_size;
		
		std::shared_ptr<interconnect_description> interconnect;
		
		std::map <std::string, std::shared_ptr<unit_description>> units;
		
		processor_description(std::string filename);
};



} // namespace scad

#endif /* SCAD_DESCRIPTION_H */
