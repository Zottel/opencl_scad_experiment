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
#include <string>
#include <regex>
#include <map>

extern "C" {
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
}

#include "util.hpp"
#include "common/instructions.h"
#include "assembly.hpp"

#include "description.hpp"

using namespace scad;

class configuration_exception : public std::runtime_error {
	public: using runtime_error::runtime_error;
};

class configuration {
	private:
		// Set by constructor
		std::string base_dir = "";
		std::string implementations_dir = "";
		processor_description proc;
		
		void translateFile(std::string file_in, std::string file_out, std::map<std::string, std::string> parameters) {
			// Check for source file readability
			if(access(file_in.c_str(), R_OK)) {
				throw configuration_exception("Could not open implementation file '" + file_in + "': " + std::strerror(errno));
			}
			
			std::ifstream in_stream(file_in);
			std::ofstream out_stream(base_dir +"/"+ file_out);
			std::string content((std::istreambuf_iterator<char>(in_stream)),
			                    std::istreambuf_iterator<char>());
			for(auto it: parameters) {
				std::string replace = "${" + it.first + "}";
				std::string with = it.second;
				
				// https://stackoverflow.com/questions/9053687/trying-to-replace-words-in-a-string
				while (content.find(replace) != std::string::npos)
				       content.replace(content.find(replace), replace.length(), with);
			}
			
			out_stream << content;
		}
		
		void create_proc_folder(std::string proc_dir) {
			if(mkdir((base_dir +"/"+ proc_dir).c_str(), S_IRWXU | S_IXGRP | S_IRGRP | S_IXOTH | S_IROTH)) {
				// directory already existing is okay.
				if(errno != EEXIST) {
					throw configuration_exception("writeProcessor: '" + proc_dir + "' could not be creatied: " + std::strerror(errno));
				}
			}
		}
	
		void writeConfig(std::string from, std::string to) {
			std::map<std::string, std::string> parameters = {
				{"BUFFER_DEPTH", std::to_string(proc.buffer_size)},
				// Number of channels taken from interconnect config for now.
				{"UNIT_COUNT", std::to_string(proc.interconnect->size)},
			};
			translateFile(from, to, parameters);
		}
		void writeChannels(std::string from, std::string to) {
			std::map<std::string, std::string> parameters = {};
			translateFile(from, to, parameters);
		}
		
		void writeBuffersH(std::string from, std::string to) {
			std::map<std::string, std::string> parameters = {};
			translateFile(from, to, parameters);
		}
		
		void writeBuffersCL(std::string from, std::string to) {
			std::map<std::string, std::string> parameters = {};
			translateFile(from, to, parameters);
		}
		
		void writeInterconnect(std::string from, std::string to) {
			std::map<std::string, std::string> parameters = {
				{"NAME", proc.interconnect->name},
			};
			translateFile(from, to, parameters);
		}
		void writeUnit(std::string from, std::string to, std::shared_ptr<unit_description> unit) {
			std::map<std::string, std::string> parameters = {
				{"NAME", unit->name},
				{"NUMBER", std::to_string(unit->number)},
			};
			
			parameters.insert(unit->parameters.begin(), unit->parameters.end());
			
			translateFile(from, to, parameters);
		}
		void writeCombineFile(std::string to, std::vector<std::string> to_include) {
			std::ofstream combined(base_dir +"/"+ to);
			combined << "// ############################################################ //" << std::endl;
			combined << "// # COMBINED FILE FOR ONE CONFIGURATION OF THE SCAD MACHINE. # //" << std::endl;
			combined << "// ############################################################ //" << std::endl;
			combined << std::endl;
			combined << std::endl;
			for(auto inc: to_include) {
				combined << "#include \"" << inc << "\"" << std::endl;
			}
			combined << std::endl;
			combined << std::endl;
		}
		
	public:
		configuration(processor_description proc, std::string implementations_dir)
			:implementations_dir(implementations_dir), proc(proc) { }
		
		void writeProcessor(std::string out_dir) {
			if(out_dir == "") {
				throw configuration_exception("writeProcessor cannot handle empty output directory.");
			}
			
			base_dir = out_dir;
			
			std::vector<std::string> to_include; // remember all files we include later on
			
			std::string proc_dir = proc.name + "_components";
			create_proc_folder(proc_dir);
			
			writeConfig(implementations_dir + "/config.cl", proc_dir + "/config.cl");
			to_include.push_back(proc_dir + "/config.cl");
			
			writeChannels(implementations_dir + "/channels.cl", proc_dir + "/channels.cl");
			to_include.push_back(proc_dir + "/channels.cl");
			
			writeBuffersCL(implementations_dir + "/buffer.cl", proc_dir + "/buffer.cl");
			to_include.push_back(proc_dir + "/buffer.cl");
			writeBuffersH(implementations_dir + "/buffer.h", proc_dir + "/buffer.h");
			to_include.push_back(proc_dir + "/buffer.h");
			
			writeInterconnect(implementations_dir + "/" + proc.interconnect->implementation + ".cl", proc_dir + "/" + proc.interconnect->implementation + ".cl");
			to_include.push_back(proc_dir + "/" + proc.interconnect->implementation + ".cl");
			
			for(std::pair<std::string, std::shared_ptr<unit_description>> unit_entry: proc.units) {
				auto unit = unit_entry.second;
				writeUnit(implementations_dir + "/" + unit->implementation + ".cl", proc_dir + "/" + std::to_string(unit->number) + "_" + unit->name + ".cl", unit);
				to_include.push_back(proc_dir + "/" + std::to_string(unit->number) + "_" + unit->name + ".cl");
			}
			
			writeCombineFile(proc.name + ".cl", to_include);
			
		}
};

// https://stackoverflow.com/questions/874134/find-if-string-ends-with-another-string-in-c
inline bool ends_with(std::string const & value, std::string const & ending) {
    if (ending.size() > value.size()) return false;
    return std::equal(ending.rbegin(), ending.rend(), value.rbegin());
}

int main (int argc, char *argv[]) {
	std::vector<std::string> args(argv+1, argv+argc);
	
	std::string description_filename = ""; // Will be set by first param
	std::string implementations_dir = "device_implementations"; // Default value - may be overridden
	
	switch(args.size())  {
		case 2:
			implementations_dir = args[1];
		case 1:
			description_filename = args[0];
			break;
		default:
		std::cout << "usage: configure <platform_description> [<implementations location>]" << std::endl;
		exit(1);
	}
	
	// Minimal sanitizing on filename
	if(!ends_with(description_filename, ".xml")) {
		std::cout << "Platform description should end in \".xml\"." << std::endl;
		exit(2);
	}
	
	// If the description filename contains a "/" then use the folder for output
	// otherwise current working directory
	std::string output_dir = description_filename;
	if(output_dir.find_last_of("/") == std::string::npos) {
		output_dir = ".";
	} else {
		output_dir.erase(output_dir.find_last_of("/"), std::string::npos);
	}
	
	try {
		processor_description proc(description_filename);
		
		try {
			configuration conf(proc, implementations_dir);
			conf.writeProcessor(output_dir);
		} catch(configuration_exception& e) {
			std::cerr << e.what() << '\n'; exit(3);
		}
	} catch(description_exception& e) {
		std::cerr << e.what() << '\n'; exit(2);
	}
	
	
	return 0;
}
