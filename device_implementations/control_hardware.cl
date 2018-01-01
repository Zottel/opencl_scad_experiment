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

#include "common/instructions.h"

#include "channels.cl"
#include "buffer.cl"

// The control unit needs to be number 0
#if ${NUMBER} > 0
#error "The control unit needs to be given number 0"
#endif

void send_move_instr_to(cl_uchar to_unit, struct scad_instruction instr) {
#ifdef EMULATOR
	printf("control: send_move_instr_to(%d)\n", to_unit);
#endif
	#pragma unroll
	for (int i = 0; i < UNIT_COUNT; i++) {
		if(i == to_unit) {
			write_channel_altera(channel_move_instructions_to[i], instr);
			mem_fence(CLK_CHANNEL_MEM_FENCE);
#ifdef EMULATOR
			printf("control: Waiting for ACK from %d.\n", to_unit);
#endif
		}
	}
	#pragma unroll
	for (int i = 0; i < UNIT_COUNT; i++) {
		if(i == to_unit) {
			read_channel_altera(channel_move_instructions_to_ack[i]);
			mem_fence(CLK_CHANNEL_MEM_FENCE);
#ifdef EMULATOR
			printf("control: Received ACK from %d.\n", to_unit);
#endif
		}
	}
}

struct scad_instruction sync_instr_to(struct scad_buffer_address to_addr) {
#ifdef EMULATOR
	printf("control: sync_instr_to(%d, %d)\n", to_addr.unit, to_addr.buffer);
#endif
	return (struct scad_instruction) {.op = SCAD_MOVE, .to = to_addr, .from = {(cl_uchar) -1,(cl_uchar) -1}};
}

void send_move_instr_from(cl_uchar from_unit, struct scad_instruction instr) {
#ifdef EMULATOR
	printf("control: send_move_instr_from(%d)\n", from_unit);
#endif
	#pragma unroll
	for (int i = 1; i < UNIT_COUNT; i++) {
		// Start at 1 because control already knows where to send immediate values.
		if(from_unit == i) {
			write_channel_altera(channel_move_instructions_from[i], instr);
			mem_fence(CLK_CHANNEL_MEM_FENCE);
		}
	}
	//write_channel_altera(channel_move_instructions_from[from_unit], instr);
}

// Used for immediate values
void send_data_packet(struct scad_data_packet packet) {
	write_channel_altera(channel_to_interconnect[0], packet);
	mem_fence(CLK_CHANNEL_MEM_FENCE);
}

// INPUT: Run input in separate kernel to simplify control unit.
channel scad_data ${NAME}_channel_branch_condition;
channel scad_data ${NAME}_channel_branch_target;
__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
kernel void ${NAME}_input() {
	#ifdef EMULATOR
		printf("control: input kernel starting.\n");
	#endif
	// Two buffers, condition and branch
	__attribute__((register)) struct scad_buffer_input input[2];
	struct scad_buffer_management input_manage =
		scad_input_init(${NUMBER}, 2, input);
	
	while(true) {
		scad_input_handle(${NUMBER}, &input_manage, input);
		if(buffer_input_has_data(&input[0])) {
			if(write_channel_nb_altera(${NAME}_channel_branch_condition, buffer_input_peek(&input[0]))) {
				#ifdef EMULATOR
					printf("control: input received branch condition: %lu\n", buffer_input_peek(&input[0]).integer);
				#endif
				buffer_input_pop(&input[0]);
			}
			mem_fence(CLK_CHANNEL_MEM_FENCE);
		}
		if(buffer_input_has_data(&input[1])) {
			if(write_channel_nb_altera(${NAME}_channel_branch_target, buffer_input_peek(&input[1]))) {
				#ifdef EMULATOR
					printf("control: input received branch address: %lu\n", buffer_input_peek(&input[1]).integer);
				#endif
				buffer_input_pop(&input[1]);
			}
			mem_fence(CLK_CHANNEL_MEM_FENCE);
		}
	}
}

enum ${NAME}_STATE {
	INVALID = 0, PROGRAM = 1, SYNC = 2, DONE = 3
};

// CONTROL: Main logic kernel, run from host.
__kernel void ${NAME}(read_only __global struct scad_instruction * restrict program,
                      cl_uint program_length) {
	enum ${NAME}_STATE state = PROGRAM;
	
	// Units that need a sync signal to know the current program has finished.
	struct scad_buffer_address sync_units[] = {${SYNC_TO}};
	cl_uint sync_units_size = (sizeof(sync_units) / sizeof(struct scad_buffer_address) ) - 1;
	
	cl_ulong pc = 0;
	
#ifdef EMULATOR
	printf("control: starting at address 0\n");
#endif
	
	while(state == PROGRAM || state == SYNC) {
		struct scad_instruction instr = (state == PROGRAM) ? program[pc] : sync_instr_to(sync_units[pc]);
		#ifdef EMULATOR
			printf("control: [state:%u] [pc:%lu] instr(op: %d, from: %d.%d, to: %d.%d)\n",
			       state, pc, instr.op, instr.from.unit, instr.from.buffer, instr.to.unit, instr.to.buffer);
		#endif
		{ // Move instruction sending.
			bool send_move = false;
			struct scad_instruction move_instr;
			if(state == PROGRAM) {
				switch(instr.op) {
					case SCAD_MOVE:
						send_move = true;
						move_instr = instr;
						break;
					case SCAD_MOVE_IMMEDIATE:
						send_move = true;
						move_instr = (struct scad_instruction)
							{.op = SCAD_MOVE, .to = instr.to, .from = {0,0}};
						break;
					default: break;
				}
				// TODO
			} else /* state == SYNC */ {
				if(instr.to.unit > 0) {
					send_move = true;
					move_instr = instr;
				}
			}
			
			// Send move:
			if(send_move) {
				send_move_instr_to(move_instr.to.unit, move_instr);
				if(move_instr.to.unit != (cl_uchar) -1) {
					send_move_instr_from(move_instr.from.unit, move_instr);
				}
			}
		}
		{ // Immediate move data
			if(instr.op == SCAD_MOVE_IMMEDIATE) {
				#ifdef EMULATOR
					printf("control: sending immediate data.\n");
				#endif
				send_data_packet((struct scad_data_packet)
				                   {.data = instr.immediate,
				                    .to = instr.to, .from = {0,0}});
				#ifdef EMULATOR
					printf("control: done sending immediate data.\n");
				#endif
			}
		}
		{ // program counter
			if(state == PROGRAM && (instr.op == SCAD_MOVE_PC)) {
				pc = instr.immediate.integer;
			} else if(state == PROGRAM
			          && (instr.op == SCAD_MOVE && instr.to.unit == 0 && instr.to.buffer == 0)) {

				scad_data branch_target = read_channel_altera(${NAME}_channel_branch_target);
				mem_fence(CLK_CHANNEL_MEM_FENCE);
				scad_data branch_condition = read_channel_altera(${NAME}_channel_branch_condition);
				mem_fence(CLK_CHANNEL_MEM_FENCE);
				#ifdef EMULATOR
					printf("control: branch (taken: %lu, target: %lu).\n", branch_condition.integer, branch_target.integer);
				#endif
				if(branch_condition.integer) {
					pc = branch_target.integer;
				} else {
					pc++;
				}
			} else {
				pc++;
			}
		}
		
		{ // state transition PROGRAM -> SYNC -> DONE
			if(state == PROGRAM) {
				if(pc > program_length) {
					state = SYNC;
					pc = 0;
				}
			} else /*S>NC*/ {
				if(pc > sync_units_size) {
					state = DONE;
				}
			}
		}
	}
	#ifdef EMULATOR
		printf("control: DONE. TERMINATING.\n");
	#endif
}

