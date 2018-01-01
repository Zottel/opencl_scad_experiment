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

/* LOAD-STORE UNIT FOR INPUT
 * INPUTS: in0 (address), in1 (value), opc (opcode, count)
 * OUTPUT: out (non for store, results for load)
 *
 * IMPORTANT:
 *   INPUT AND OUTPUT MEMORY MUST NOT OVERLAP.
 */

#include "common/instructions.h"

#include "channels.cl"
#include "buffer.h"

// LSU
// 3 inputs: in0, in1, opc
#define SCAD_LSU_INPUT_NUM 3
// 1 output: out
#define SCAD_LSU_OUTPUT_NUM 1

// Output kernel
// It's simpler to have output in an extra kernel
// to remove "terminated but output pending" case.
channel scad_data ${NAME}_channel_output;
__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
kernel void ${NAME}_external_output() {
	// Two buffers, condition and branch
	__attribute__((register)) struct scad_buffer_output output[SCAD_LSU_OUTPUT_NUM];
	__attribute__((register)) struct scad_buffer_management output_manage =
		scad_output_init(${NUMBER}, SCAD_LSU_OUTPUT_NUM, output);
	
	while(true) {
		bool data_read;
		scad_data data;
		
		if(!buffer_output_data_full(&output[0])) {
			data = read_channel_nb_altera(${NAME}_channel_output, &data_read);
			
			if(data_read) {
				#ifdef EMULATOR
					printf("[${NAME}_external_output] has output data.\n");
				#endif
				buffer_output_push_data(&output[0], data);
			}
		}
		
		scad_output_handle(${NUMBER}, &output_manage, output);
	}
}

// Input kernel
// Separate kernel to not loose any state on lsu termination.
channel bool ${NAME}_channel_input_sync
	__attribute__((depth(1)));
channel scad_data ${NAME}_channel_input_address
	__attribute__((depth(1)));
channel scad_data ${NAME}_channel_input_value
	__attribute__((depth(1)));
channel scad_data ${NAME}_channel_input_opc
	__attribute__((depth(1)));

__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
__kernel void ${NAME}_external_input() {
#ifdef EMULATOR
	printf("[${NAME}_external_input] starting with id ${NUMBER}\n");
#endif
	// Two buffers, condition and branch
	__attribute__((register)) struct scad_buffer_input input[SCAD_LSU_INPUT_NUM];
	__attribute__((register)) struct scad_buffer_management input_manage =
		scad_input_init(${NUMBER}, SCAD_LSU_INPUT_NUM, input);
	
	while(true) {
		scad_input_handle(${NUMBER}, &input_manage, input);
		
		if(buffer_input_has_marker(&input[2])
		   ||(buffer_input_has_data(&input[0])
		      && buffer_input_has_data(&input[1])
		      && buffer_input_has_data(&input[2]))) {
			bool sync_value = buffer_input_has_marker(&input[2]);
			write_channel_altera(${NAME}_channel_input_sync,  sync_value);
			mem_fence(CLK_CHANNEL_MEM_FENCE);
			
			if(!sync_value) {
				write_channel_altera(${NAME}_channel_input_opc, buffer_input_pop(&input[2]));
				mem_fence(CLK_CHANNEL_MEM_FENCE);
				write_channel_altera(${NAME}_channel_input_address, buffer_input_pop(&input[0]));
				mem_fence(CLK_CHANNEL_MEM_FENCE);
				write_channel_altera(${NAME}_channel_input_value, buffer_input_pop(&input[1]));
				mem_fence(CLK_CHANNEL_MEM_FENCE);
			}
		}
	}
}


__kernel void ${NAME}(read_only __global scad_data * restrict mem_input,
                      read_only cl_uint mem_input_length) {
	
#ifdef EMULATOR
	printf("load_store for input starting with id %d\n", ${NUMBER});
#endif
	__attribute__((register)) struct scad_buffer_input input[SCAD_LSU_INPUT_NUM];
	__attribute__((register)) struct scad_buffer_management input_manage =
		scad_input_init(${NUMBER}, SCAD_LSU_INPUT_NUM, input);
	
	// Data copies that still need to be stored in the output buffer.
	scad_data pending_data;
	cl_uchar pending_copies = 0;
	
	bool finished = false;
	
	while(!finished) {
		// Handle receiving data.
		scad_input_handle(${NUMBER}, &input_manage, input);
		
		// SYNC MARKER
		if(buffer_input_has_marker(&input[2])) {
#ifdef EMULATOR
			printf("load-store-input: Received sync marker. terminating.\n");
#endif
			
			// Handle sync markers (i.e. termination message).
			buffer_input_pop(&input[2]);
			finished = true;
		
		// REGULAR INSTRUCTIONS?
		} else if(pending_copies == 0
		          && buffer_input_has_data(&input[0])
		          && buffer_input_has_data(&input[1])
		          && buffer_input_has_data(&input[2])) {
			// No more pending copies and all inputs are available
			// Execute next operation
			scad_data address = buffer_input_pop(&input[0]); // lsu.in0
			scad_data value = buffer_input_pop(&input[1]); // lsu.in1
			scad_data opc = buffer_input_pop(&input[2]); // lsu.opc
			
			switch(opc.op.opcode) {
				case SCAD_LSU_STORE:
#ifdef EMULATOR
					printf("load-store-input: ERROR: RECEIVED A STORE. Value 0x%lx to address 0x%lx.\n", value.integer, address.integer);
#endif
					break;
				case SCAD_LSU_LOAD:
#ifdef EMULATOR
					printf("load-store-input: RECEIVED A LOAD: Address 0x%lx with 0x%x copies.\n", address.integer, opc.op.count);
#endif
					if(address.integer < mem_input_length) {
						pending_data = mem_input[address.integer];
						pending_copies = opc.op.count;
					} else {
#ifdef EMULATOR
						printf("load-store-input: ERROR: Address 0x%lx is out of bounds!\n", address.integer);
#endif
					}
					break;
				case SCAD_LSU_INVALID:
				default:
#ifdef EMULATOR
					printf("load-store-input: ERROR: Invalid OPCODE: 0x%x\n", opc.op.opcode);
#endif
					break;
			}
		}
		
		// Send pending data to output kernel.
		while(pending_copies > 0) {
#ifdef EMULATOR
			//printf("load-store: pushing data to output: 0x%x (0x%lx copies remaining).\n", pending_data.integer, pending_copies);
#endif
			write_channel_altera(${NAME}_channel_output, pending_data);
			pending_copies--;
		}
	}
}

