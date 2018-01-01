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

#include "assembly.hpp"

namespace scad {

void assembly::push_label(std::string label) {
	//std::cout << "label: \"" << label << "\" -> " << result.size() << std::endl;
	if(symbol.count(label) > 0) {
		throw assembly_exception("Duplicate label: " + label);
	}
	symbol[label] = result.size();
}

std::pair<bool, scad_data> assembly::parse_immediate(std::string immediate_string) {
	
	std::regex integer_pattern("\\$([0-9]+)");
	std::smatch integer_match;
	if(std::regex_match(immediate_string, integer_match, integer_pattern)) {
		scad_data result = {.integer =  std::stoul(integer_match[1])};
		return std::make_pair(true, result);
	}
	
	if(immediate_string == "st") {
		scad_data result = {.op.opcode = lsu_op_strings["st"],
		                    .op.count = 1};
		return std::make_pair(true, result);
		//return std::make_pair(true, lsu_op_strings["st"]);
	}
	
	std::regex tuple_pattern("\\(\\s*([^\\s\\,]+)\\s*\\,\\s*([0-9]+)\\s*\\)");
	std::smatch tuple_match;
	if(std::regex_match(immediate_string, tuple_match, tuple_pattern)) {
		unsigned long count = std::stoul(tuple_match[2]);
		scad_data result = {.op.opcode = 0,
		                    .op.count = (cl_uint) count};
		std::string opcode = tuple_match[1];
		
		if(lsu_op_strings.count(opcode)) {
			result.op.opcode = lsu_op_strings[opcode];
		} else if(pu_op_strings.count(opcode)) {
			result.op.opcode = pu_op_strings[opcode];
		} else {
			throw assembly_exception("No corresponding opcode found for \""
			                         + opcode + "\" in: " + immediate_string);
		}
		return std::make_pair(true, result);
	}
	
	return std::make_pair(false, (scad_data {.integer = 0}));
}

std::pair<bool, std::string> assembly::parse_label_from(std::string label_str) {
	std::regex label_pattern("^[a-zA-Z_][a-zA-Z_0-9]*$");
	std::smatch label_match;
	if(std::regex_match(label_str, label_match, label_pattern)) {
		return {true, label_str};
	} else {
		return {false, ""};
	}
}

std::pair<bool, std::pair<std::string, std::string>> split_buffer_address(std::string buffer_str) {
	std::regex buffer_pattern("^([a-zA-Z_0-9]+)@([a-zA-Z_0-9]+)$");
	std::smatch buffer_match;
	if(std::regex_match(buffer_str, buffer_match, buffer_pattern)) {
		return std::make_pair(true, std::make_pair(buffer_match[1], buffer_match[2]));
	}
	return std::make_pair(false, std::make_pair("", ""));
}

std::pair<bool, struct scad_buffer_address> assembly::parse_address_from(std::string addr_str) {
	std::pair<bool, std::pair<std::string, std::string>> split_addr = split_buffer_address(addr_str);
	if(split_addr.first) {
		if(proc.units.count(split_addr.second.first) == 0) {
			throw assembly_exception("Source unit '" + split_addr.second.first + "' not found in: " + addr_str);
		}
		
		if(proc.units.at(split_addr.second.first)->output_buffers.count(split_addr.second.second) == 0) {
			throw assembly_exception("Source buffer '" + split_addr.second.second + "' not found in: " + addr_str);
		}
		
		return std::make_pair(true, proc.units.at(split_addr.second.first)->output_buffers.at(split_addr.second.second));
	} else {
		return std::make_pair(false, (struct scad_buffer_address) {});
	}
}

std::pair<bool, struct scad_buffer_address> assembly::parse_address_to(std::string addr_str) {
	std::pair<bool, std::pair<std::string, std::string>> split_addr = split_buffer_address(addr_str);
	if(split_addr.first) {
		if(proc.units.count(split_addr.second.first) == 0) {
			throw assembly_exception("Destination unit '" + split_addr.second.first + "' not found in: " + addr_str);
		}
		
		if(proc.units.at(split_addr.second.first)->input_buffers.count(split_addr.second.second) == 0) {
			throw assembly_exception("Destination buffer '" + split_addr.second.second + "' not found in: " + addr_str);
		}
		
		return std::make_pair(true, proc.units.at(split_addr.second.first)->input_buffers.at(split_addr.second.second));
	} else {
		// Destroying move.
		if(addr_str == "null") {
			return std::make_pair(true, (struct scad_buffer_address) {.unit = (cl_uchar) -1, .buffer = (cl_uchar) -1});
		}
		return std::make_pair(false, (struct scad_buffer_address) {});
	}
}

void assembly::push_move(std::string from, std::string to) {
	//std::cout << "move: \"" << from << "\" -> \"" << to << "\"" << std::endl;
	struct scad_instruction instr;
	
	// (bool, value) results from parsing attempts
	auto from_imm = parse_immediate(from);
	auto from_addr = parse_address_from(from);
	auto from_label = parse_label_from(from);
	
	if(from_imm.first) {
		instr.immediate = from_imm.second;
		instr.op = SCAD_MOVE_IMMEDIATE;
	} else if(from_addr.first) {
		instr.from = from_addr.second;
		instr.op = SCAD_MOVE;
	} else if(from_label.first) {
		instr.op = SCAD_MOVE_IMMEDIATE;
		instr.immediate.integer = 0;
		unlinked[result.size()] = from_label.second;
	} else {
		throw assembly_exception("Source for move is neither address nor immediate value in: "
		                         + from + " -> " + to);
	}
	
	if(to == "pc") {
		if(!from_imm.first && !from_label.first) {
			throw assembly_exception("Only immediate or label moves to pc supported: "
			                         + from + " -> " + to);
		} else {
			instr.op = SCAD_MOVE_PC;
		}
	} else { // no move to pc
		auto to_addr = parse_address_to(to);
		if(to_addr.first) {
			instr.to = to_addr.second;
		} else {
			throw assembly_exception("Destination is no address in: "
			                         + from + " -> " + to);
		}
	}
	
	result.push_back(instr);
}

assembly::assembly(processor_description proc)
	:proc(proc) {
	
}


std::vector<struct scad_instruction> assembly::build() {
	for(auto it: unlinked) {
		if(symbol.count(it.second) > 0) {
			result[it.first].immediate.integer = (unsigned long) symbol[it.second];
		} else {
			throw assembly_exception("Unknown reference to "
			                         + it.second);// + " at instruction " + it.first);
		}
	}
	
	return result;
}

void assembly::parse(std::string program_str) {
	// patterns (descending priority):
	// comment: //.*
	// label: [\\w]+:
	// a->b, a.x -> c.i, $ias -> a.b: [\\w.$]+\\s*->\\s*[\\w.]+)
	// (askdj, asd) -> a.b: \\(\\s*[\\w.]+\\s*,\\s*[\\w.]+\\s*\\)\\s*->\\s*[\\w.]+
	std::regex pattern("(//.*)"
	                   "|([\\w]+)[\\s]*:"
	                   "|(([\\w.$@]+)\\s*->\\s*([\\w.@]+))"
	                   "|((\\(\\s*[\\w.]+\\s*,\\s*[\\w.]+\\s*\\))\\s*->\\s*([\\w.@]+))");
	
	std::sregex_iterator it(program_str.begin(), program_str.end(), pattern);
	std::sregex_iterator end;
	for(; it != end; ++it) {
		std::smatch match = *it;
		//std::cout << match[0] << std::endl;
		if(match.length(1) > 0) {
			// comment
			// std::cout << match[1] << std::endl;
		} else if(match.length(2) > 0) {
			push_label(match[2]);
		} else if(match.length(3) > 0) {
			push_move(match[4], match[5]);
		} else if(match.length(6) > 0) {
			push_move(match[7], match[8]);
		}
	}

}

} // namespace scad
