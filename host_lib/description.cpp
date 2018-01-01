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

#include "pugixml.hpp"

#include "common/instructions.h"
#include "unit_types.hpp"
#include "description.hpp"


namespace scad {

unit_description::unit_description(std::string name, std::string type,
                                   std::string implementation, int number,
                                   std::map<std::string, std::string> parameters)
:name(name), type(type), implementation(implementation), number(number), parameters(parameters) {
	//std::map<std::string, std::pair<std::map<std::string, int>, std::map<std::string, int>>> const unit_type_buffers
	if(unit_type_buffers.count(type) == 0) {
		throw description_exception("Unit type '" + type + "' is unknown.");
	}
	
	auto unit_buffers = unit_type_buffers.at(type);
	auto inputs = unit_buffers.first;
	auto outputs = unit_buffers.second;
	
	for(std::pair<std::string, int> it: inputs) {
		input_buffers[it.first] = (struct scad_buffer_address) {.unit = (cl_uchar) number, .buffer = (cl_uchar) it.second};
	}
	
	for(std::pair<std::string, int> it: outputs) {
		output_buffers[it.first] = (struct scad_buffer_address) {.unit = (cl_uchar) number, .buffer = (cl_uchar) it.second};
	}
}

processor_description::processor_description(std::string filename) {
	pugi::xml_document doc;
	
	std::ifstream stream(filename);
	pugi::xml_parse_result result = doc.load(stream);
	
	pugi::xml_node processor_node = doc.child("processor");
	
	name = processor_node.attribute("name").value();
	buffer_size = processor_node.attribute("buffersize").as_int();
	//std::cout << std::endl;
	//std::cout << "processor '" << name << "' with buffer size: " << buffer_size << std::endl;
	
	// all children
	for (pugi::xml_node unit: processor_node.children("unit")) {
		std::string name = unit.child("name").text().get();
		std::string type = unit.child("type").text().get();
		std::string implementation = unit.child("implementation").text().get();
		int number = unit.child("number").text().as_int();
		std::map<std::string, std::string> parameters;
		for (pugi::xml_node unit_parameter = unit.child("parameter");
		     unit_parameter;
		     unit_parameter = unit_parameter.next_sibling("parameter")) {
			parameters.insert(std::make_pair(unit_parameter.child("key").text().get(),
			                                 unit_parameter.child("value").text().get()));
		}
		
		
		if(this->units.count(name) > 0) {
			throw description_exception("Two units with name '" + name + "' in file '" + filename + "'");
		}
		this->units[name] = std::shared_ptr<unit_description>(new unit_description(name, type, implementation, number, parameters));
	}
	
	bool interconnect_found = false;
	
	for (pugi::xml_node interconnect: processor_node.children("interconnect")) {
		if(interconnect_found) {
			throw description_exception("Two interconnects given in file: " + filename);
		}
		interconnect_found = true;
		
		std::string name = interconnect.child("name").text().get();
		std::string implementation = interconnect.child("implementation").text().get();
		int size = interconnect.child("size").text().as_int();
		
		this->interconnect = std::shared_ptr<interconnect_description>(new interconnect_description(name, implementation, size));
	}
	
	if(!interconnect_found) {
		throw description_exception("No interconnect given in file: " + filename);
	}
}






} // namespace scad
