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
channel scad_data ${NAME}_channel_output
	__attribute__((depth(2)));
__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
__kernel void ${NAME}_external_output() {
#ifdef EMULATOR
	printf("[${NAME}_external_output] starting with id ${NUMBER}\n");
#endif
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
// It's simpler to have output in an extra kernel
// to remove "terminated but output pending" case.
channel bool ${NAME}_channel_input_sync
	__attribute__((depth(1)));
channel scad_data ${NAME}_channel_input_address
	__attribute__((depth(1)));
channel scad_data ${NAME}_channel_input_value
	__attribute__((depth(1)));
channel scad_data ${NAME}_channel_input_opc
	__attribute__((depth(1)));

enum ${NAME}_INSTATE {
	${NAME}_INSTATE_INVALID = 0, ${NAME}_INSTATE_OPC = 1, ${NAME}_INSTATE_ADDRESS = 2, ${NAME}_INSTATE_DATA = 3
};

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
	
	enum ${NAME}_INSTATE state = ${NAME}_INSTATE_OPC;
	
	while(true) {
		scad_input_handle(${NUMBER}, &input_manage, input);
		
		
		if(state == ${NAME}_INSTATE_OPC) {
			if(write_channel_nb_altera(${NAME}_channel_input_opc,
				                         buffer_input_peek(&input[2]))) {
				#ifdef EMULATOR
					printf("[${NAME}_external_input] relaying opcode %lu\n", buffer_input_peek(&input[2]).integer);
				#endif
				buffer_input_pop(&input[2]);
				state = ${NAME}_INSTATE_ADDRESS;
			}
		}
		
		
		if(state == ${NAME}_INSTATE_ADDRESS
		   && buffer_input_has_data(&input[0])) {
			if(write_channel_nb_altera(${NAME}_channel_input_address,
				                         buffer_input_peek(&input[0]))) {
				#ifdef EMULATOR
					printf("[${NAME}_external_input] relaying address %lu\n", buffer_input_peek(&input[0]).integer);
				#endif
				buffer_input_pop(&input[0]);
				state = ${NAME}_INSTATE_DATA;
			}
			mem_fence(CLK_CHANNEL_MEM_FENCE);
		}
		
		if(state == ${NAME}_INSTATE_DATA
		   && buffer_input_has_data(&input[1])) {
			if(write_channel_nb_altera(${NAME}_channel_input_value,
				                         buffer_input_peek(&input[1]))) {
				#ifdef EMULATOR
					printf("[${NAME}_external_input] relaying value %lu\n", buffer_input_peek(&input[1]).integer);
				#endif
				buffer_input_pop(&input[1]);
				state = ${NAME}_INSTATE_OPC;
			}
			mem_fence(CLK_CHANNEL_MEM_FENCE);
		}
		
	}
}

__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
__kernel void ${NAME}() {
	scad_data mem[${MEMORY_SIZE}];
#ifdef EMULATOR
	printf("[${NAME}] starting with id ${NUMBER}\n");
#endif
	while(true) {
		#ifdef EMULATOR
			printf("[${NAME}] SYNC(false) received");
		#endif
		scad_data opc = read_channel_altera(${NAME}_channel_input_opc);
		mem_fence(CLK_CHANNEL_MEM_FENCE);
		scad_data address = read_channel_altera(${NAME}_channel_input_address);
		mem_fence(CLK_CHANNEL_MEM_FENCE);
		scad_data value = read_channel_altera(${NAME}_channel_input_value);
		mem_fence(CLK_CHANNEL_MEM_FENCE);
		#ifdef EMULATOR
			printf("[${NAME}] RECEIVED A TRIPLE\n");
		#endif
		
		
		switch(opc.op.opcode) {
			case SCAD_LSU_STORE:
#ifdef EMULATOR
				printf("[${NAME}] RECEIVED A STORE. Value 0x%lx to address 0x%lx.\n", value.integer, address.integer);
#endif
				if(address.integer < ${MEMORY_SIZE}) {
					mem[address.integer] = value;
				} else {
#ifdef EMULATOR
					printf("[${NAME}] ERROR: invalid address: 0x%lx\n", address.integer);
#endif
				}
				break;
			
			case SCAD_LSU_LOAD:
#ifdef EMULATOR
				printf("[${NAME}] RECEIVED A LOAD: Address 0x%lx with 0x%x copies.\n", address.integer, opc.op.count);
#endif
				if(address.integer < ${MEMORY_SIZE}) {
					scad_data pending_data = mem[address.integer];
					cl_uint pending_copies = opc.op.count;
					
					// Send pending data to output kernel.
					while(pending_copies > 0) {
			#ifdef EMULATOR
						//printf("[${NAME}] pushing data to output: 0x%x (0x%lx copies remaining).\n", pending_data.integer, pending_copies);
			#endif
						write_channel_altera(${NAME}_channel_output, pending_data);
						mem_fence(CLK_CHANNEL_MEM_FENCE);
						pending_copies--;
					}
				} else {
#ifdef EMULATOR
					printf("[${NAME}] ERROR: invalid address: 0x%lx\n", address.integer);
#endif
				}
				break;
			case SCAD_LSU_INVALID:
			default:
#ifdef EMULATOR
				printf("[${NAME}] ERROR: Invalid OPCODE: 0x%x\n", opc.op.opcode);
#endif
				break;
		}
		
		#ifdef EMULATOR
			printf("[${NAME}] TRIPLE HANDLED.\n");
		#endif
	}
	#ifdef EMULATOR
		printf("[${NAME}] DONE. TERMINATING.\n");
	#endif
}

