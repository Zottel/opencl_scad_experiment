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

/* LOAD-STORE UNIT
 * INPUTS: in0 (address), in1 (value), opc (opcode, count)
 * OUTPUT: out (non for store, results for load)
 *
 * MEMORY AREAS:
 * switch (address >> 62) {
 *     case 0: // "LOCAL" RAM - not used outside of load-store unit
 *     case 1: // "INPUT" MEMORY
 *     case 2: // "OUTPUT" MEMORY
 *     case 3: // UNASSIGNED
 * }
 * 
 * IMPORTANT:
 *   INPUT AND OUTPUT MEMORY MUST NOT OVERLAP.
 */


#include "common/instructions.h"

#include "channels.cl"
#include "buffer.h"


// RAM ONLY ACCESSED BY THIS LSU
#define ${NAME}_MEMORY_SIZE 1024
__global scad_data ${NAME}_memory[${NAME}_MEMORY_SIZE];

// LSU
// 3 inputs: in0, in1, opc
#define SCAD_LSU_INPUT_NUM 3
// 1 output: out
#define SCAD_LSU_OUTPUT_NUM 1

__kernel void ${NAME}(read_only __global scad_data * restrict mem_input,
                      read_only cl_uint mem_input_length,
                      write_only __global scad_data * restrict mem_output,
                      read_only cl_uint mem_output_length) {
#ifdef EMULATOR
	printf("load_store starting with id %d\n", ${NUMBER});
#endif
	struct scad_buffer_input input[SCAD_LSU_INPUT_NUM];
	struct scad_buffer_management input_manage =
		scad_input_init(${NUMBER}, SCAD_LSU_INPUT_NUM, input);
	
	struct scad_buffer_output output[SCAD_LSU_OUTPUT_NUM];
	struct scad_buffer_management output_manage =
		scad_output_init(${NUMBER}, SCAD_LSU_OUTPUT_NUM, output);
	
	// Data copies that still need to be stored in the output buffer.
	scad_data pending_data;
	cl_uchar pending_copies = 0;
	
	bool finished = false;
	
	while(!finished) {
		// Handle receiving data.
		scad_input_handle(${NUMBER}, &input_manage, input);
		
		if(buffer_input_has_marker(&input[2])) {
#ifdef EMULATOR
			printf("load-store: Received sync marker. terminating.\n");
#endif
			// Handle sync markers (i.e. termination message).
			buffer_input_pop(&input[2]);
			finished = true;
		
		} else if(pending_copies == 0
		          && buffer_input_has_data(&input[0])
		          && buffer_input_has_data(&input[1])
		          && buffer_input_has_data(&input[2])) {
			// No more pending copies and all inputs are available
			// Execute next operation
			scad_data address = buffer_input_pop(&input[0]); // lsu.in0
			scad_data value = buffer_input_pop(&input[1]); // lsu.in1
			scad_data opc = buffer_input_pop(&input[2]); // lsu.opc
			
			cl_uchar address_prefix = (address.integer >> 62) & 0x03;
			cl_ulong address_offset = address.integer ^ (address_prefix << 62);
			
			switch(opc.op.opcode) {
				case SCAD_LSU_STORE:
#ifdef EMULATOR
					printf("load-store: RECEIVED A STORE. Value 0x%lx to address 0x%lx.\n", value.integer, address.integer);
#endif
					
					switch (address_prefix) {
						case 0: // "LOCAL" RAM - not used outside of load-store unit
							if(address_offset < ${NAME}_MEMORY_SIZE) {
								${NAME}_memory[address_offset] = value;
							} else {
#ifdef EMULATOR
								printf("load-store: ERROR: invalid address: 0x%lx\n", address.integer);
#endif
							}
							break;
						case 1: // "INPUT" MEMORY
#ifdef EMULATOR
							printf("load-store: ERROR: STORE TO INPUT MEMORY: 0x%lx\n", address.integer);
#endif
							break;
						case 2: // "OUTPUT" MEMORY
							if(address_offset < mem_output_length) {
								mem_output[address_offset] = value;
							} else {
#ifdef EMULATOR
								printf("load-store: ERROR: invalid address: 0x%lx\n", address.integer);
#endif
							}
							break;
						default:
#ifdef EMULATOR
							printf("load-store: write to unassigned memory\n");
#endif
							break;
					}
					break;
				case SCAD_LSU_LOAD:
#ifdef EMULATOR
					printf("load-store: RECEIVED A LOAD: Address 0x%lx with 0x%x copies.\n", address.integer, opc.op.count);
#endif
					switch (address_prefix) {
						case 0: // "LOCAL" RAM - not used outside of load-store unit
							if(address_offset < ${NAME}_MEMORY_SIZE) {
								pending_data = ${NAME}_memory[address_offset];
								pending_copies = opc.op.count;
							} else {
#ifdef EMULATOR
								printf("load-store: ERROR: invalid address: 0x%lx\n", address.integer);
#endif
							}
							break;
						case 1: // "INPUT" MEMORY
							if(address_offset < mem_input_length) {
								pending_data = mem_input[address_offset];
								pending_copies = opc.op.count;
							} else {
#ifdef EMULATOR
								printf("load-store: ERROR: invalid address: 0x%lx\n", address.integer);
#endif
							}
							break;
						case 2: // "OUTPUT" MEMORY
#ifdef EMULATOR
							printf("load-store: ERROR: LOAD FROM OUTPUT MEMORY: 0x%lx\n", address.integer);
#endif
							break;
						default: // UNASSIGNED
#ifdef EMULATOR
							printf("load-store: read from unassigned memory");
#endif
							break;
					}
					break;
				case SCAD_LSU_INVALID:
				default:
#ifdef EMULATOR
					printf("load-store: ERROR: Invalid OPCODE: 0x%x\n", opc.op.opcode);
#endif
					break;
			}
		}
		
		// Copy pending data to output buffer if there is space available.
		while(pending_copies > 0 && !buffer_output_data_full(&output[0])) {
#ifdef EMULATOR
			//printf("load-store: pushing data to output: 0x%x (0x%lx copies remaining).\n", pending_data.integer, pending_copies);
#endif
			buffer_output_push_data(&output[0], pending_data);
			pending_copies--;
#ifdef EMULATOR
			//printf("load-store. state of lsu.out: (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
			//      output[0].to_full, output[0].data_full, output[0].start, output[0].to_end, output[0].data_end);
#endif
		}
		
		// Buffer send handling.
		scad_output_handle(${NUMBER}, &output_manage, output);
#ifdef EMULATOR
		//printf("load-store. post-handling: state of lsu.out: (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
		//      output[0].to_full, output[0].data_full, output[0].start, output[0].to_end, output[0].data_end);
#endif
	}
	
#ifdef EMULATOR
	printf("load-store: debug 1");
#endif
	// Finish execution
	while(pending_copies > 0 || !buffer_output_data_empty(&output[0])) {
		// Copy pending data to output buffer if there is space available.
		while(pending_copies > 0 && !buffer_output_data_full(&output[0])) {
#ifdef EMULATOR
			//printf("load-store: pushing data to output: 0x%x (0x%lx copies remaining).\n", pending_data.integer, pending_copies);
#endif
			buffer_output_push_data(&output[0], pending_data);
			pending_copies--;
#ifdef EMULATOR
			//printf("load-store. state of lsu.out: (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
			//      output[0].to_full, output[0].data_full, output[0].start, output[0].to_end, output[0].data_end);
#endif
		}
		
		// Buffer send handling.
		scad_output_handle(${NUMBER}, &output_manage, output);
#ifdef EMULATOR
		//printf("load-store. post-handling: state of lsu.out: (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
		//      output[0].to_full, output[0].data_full, output[0].start, output[0].to_end, output[0].data_end);
#endif
	}
	
}

