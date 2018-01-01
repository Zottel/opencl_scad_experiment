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

// The control unit needs to be number 0
#if ${NUMBER} > 0
#error "The control unit needs to be given number 0"
#endif

void send_move_instr_to(cl_uchar to_unit, struct scad_instruction instr) {
#ifdef EMULATOR
	printf("control: send_move_instr_to(%d)\n", to_unit);
	write_channel_altera(channel_move_instructions_to[to_unit], instr);
#else
	switch(to_unit) {
                case 0: write_channel_altera(channel_move_instructions_to[0], instr); break;
                case 1: write_channel_altera(channel_move_instructions_to[1], instr); break;
                case 2: write_channel_altera(channel_move_instructions_to[2], instr); break;
                case 3: write_channel_altera(channel_move_instructions_to[3], instr); break;
                case 4: write_channel_altera(channel_move_instructions_to[4], instr); break;
                case 5: write_channel_altera(channel_move_instructions_to[5], instr); break;
                case 6: write_channel_altera(channel_move_instructions_to[6], instr); break;
                case 7: write_channel_altera(channel_move_instructions_to[7], instr); break;
                case 8: write_channel_altera(channel_move_instructions_to[8], instr); break;
                case 9: write_channel_altera(channel_move_instructions_to[9], instr); break;
                case 10: write_channel_altera(channel_move_instructions_to[10], instr); break;
                case 11: write_channel_altera(channel_move_instructions_to[11], instr); break;
                case 12: write_channel_altera(channel_move_instructions_to[12], instr); break;
                case 13: write_channel_altera(channel_move_instructions_to[13], instr); break;
                case 14: write_channel_altera(channel_move_instructions_to[14], instr); break;
                case 15: write_channel_altera(channel_move_instructions_to[15], instr); break;
                case 16: write_channel_altera(channel_move_instructions_to[16], instr); break;
                case 17: write_channel_altera(channel_move_instructions_to[17], instr); break;
                case 18: write_channel_altera(channel_move_instructions_to[18], instr); break;
                case 19: write_channel_altera(channel_move_instructions_to[19], instr); break;
                case 20: write_channel_altera(channel_move_instructions_to[20], instr); break;
                case 21: write_channel_altera(channel_move_instructions_to[21], instr); break;
                case 22: write_channel_altera(channel_move_instructions_to[22], instr); break;
                case 23: write_channel_altera(channel_move_instructions_to[23], instr); break;
                case 24: write_channel_altera(channel_move_instructions_to[24], instr); break;
                case 25: write_channel_altera(channel_move_instructions_to[25], instr); break;
                case 26: write_channel_altera(channel_move_instructions_to[26], instr); break;
                case 27: write_channel_altera(channel_move_instructions_to[27], instr); break;
                case 28: write_channel_altera(channel_move_instructions_to[28], instr); break;
                case 29: write_channel_altera(channel_move_instructions_to[29], instr); break;
                case 30: write_channel_altera(channel_move_instructions_to[30], instr); break;
                case 31: write_channel_altera(channel_move_instructions_to[31], instr); break;
		default: break;
	}
	mem_fence(CLK_CHANNEL_MEM_FENCE);
#endif
	// Wait for ACK
#ifdef EMULATOR
	printf("control: Waiting for ACK from %d.\n", to_unit);
#endif
	read_channel_altera(channel_move_instructions_to_ack[to_unit]);
#ifdef EMULATOR
	printf("control: Received ACK from %d.\n", to_unit);
#endif
}

void send_move_sync(struct scad_buffer_address addr) {
#ifdef EMULATOR
	printf("control: sending sync to 0x%x.0x%x.\n", addr.unit, addr.buffer);
#endif
	send_move_instr_to(addr.unit, (struct scad_instruction)
	                   {.op = SCAD_MOVE,
	                    .to = addr, .from = {(cl_uchar) -1,(cl_uchar) -1}});
#ifdef EMULATOR
	printf("control: done sending sync to 0x%x.0x%x.\n", addr.unit, addr.buffer);
#endif
}


void send_move_instr_from(cl_uchar from_unit, struct scad_instruction instr) {
#ifdef EMULATOR
	printf("control: send_move_instr_from(%d)\n", from_unit);
#endif
	write_channel_altera(channel_move_instructions_from[from_unit], instr);
}

// Used for immediate values
void send_data_packet(struct scad_data_packet packet) {
	write_channel_altera(channel_to_interconnect[0], packet);
}

/*
void send_move_instr(cl_uchar to_unit, struct scad_instruction instr) {
	switch(to_unit) {
		case 0:
#ifdef EMULATOR
			printf("Sending data through channel 0\n");
#endif
			write_channel_altera(channel_move_instructions[0], instr);
			break;
		
		// ...
	}
}
*/

// Might speed up the program reads.
__kernel void ${NAME}(read_only __global struct scad_instruction program[],
                           read_only cl_uint program_length) {
	cl_ulong pc = 0;
	cl_ulong branch_target = 0;
	bool branch_valid = false;
	
#ifdef EMULATOR
	printf("control: starting at address 0\n");
#endif
	
	while(pc < program_length) {
		struct scad_instruction instr = program[pc];
		switch(instr.op) {
			
			case SCAD_MOVE:
#ifdef EMULATOR
					printf("control: move %d.%d -> %d.%d\n", instr.from.unit, instr.from.buffer, instr.to.unit, instr.to.buffer);
#endif
					
					// Move to branch condition: stall until arrival then branch.
					if(instr.to.unit == 0 && instr.to.buffer == 0) {
						send_move_instr_from(instr.from.unit, instr);
#ifdef EMULATOR
						printf("control: Waiting for branch condition.\n");
#endif
						struct scad_data_packet branch_result = read_channel_altera(channel_from_interconnect[0]);
#ifdef EMULATOR
						printf("control: Received branch condition.\n");
#endif
#ifdef EMULATOR
						if(branch_result.from.unit != instr.from.unit
							 || branch_result.from.buffer != instr.from.buffer) {
							printf("ERROR: Received branch condition from %d.%d, but expected to receive from %d.%d",
							       instr.from.unit, instr.from.buffer, branch_result.from.unit, branch_result.from.buffer);
						}
						if(!branch_valid) {
							printf("ERROR: Invalid branch target executing branch at pc = %lu.\n", pc);
						}
#endif /* EMULATOR*/
						if(branch_result.data.integer) {
							pc = branch_target;
						} else {
							pc++;
						}
						branch_valid = false;
					
					// Else: Normal move, send the instruction to sender and receiver
					} else {
						if(instr.to.unit != (cl_uchar) -1) {
#ifdef EMULATOR
							printf("control: sending move to destination\n");
#endif
							send_move_instr_to(instr.to.unit, instr);
						}
						
#ifdef EMULATOR
						printf("control: sending move to source\n");
#endif
						send_move_instr_from(instr.from.unit, instr);
						pc++;
					}
				break;
			
			case SCAD_MOVE_IMMEDIATE:
					// Immediate move to branch target
					if(instr.to.unit == 0 && instr.to.buffer == 1) {
#ifdef EMULATOR
						printf("control: branch target set to: $0x%lx\n", instr.immediate.integer);
#endif
						// Just remember branch target for now.
						branch_target = instr.immediate.integer;
						branch_valid = true;
					
					// Immediate move to functional unit input buffer
					} else {
#ifdef EMULATOR
						printf("control: move_immediate $0x%lx -> %d.%d\n", instr.immediate.integer, instr.to.unit, instr.to.buffer);
#endif
						// This performs the immediate move in two stages:
						// 1) Signal receiving unit to receive data value from 0.0 (ctrl.out)
						// 2) Send immediate value through data network.
						send_move_instr_to(instr.to.unit, (struct scad_instruction)
							{.op = SCAD_MOVE,
							 .to = instr.to, .from = {0,0}});
						send_data_packet((struct scad_data_packet)
							{.data = instr.immediate,
							 .to = instr.to, .from = {0,0}});
					}
					pc++;
				break;
			
			case SCAD_MOVE_PC:
#ifdef EMULATOR
					printf("control: move_pc $0x%lx -> %d.%d\n", instr.immediate.integer, instr.to.unit, instr.to.buffer);
#endif
					pc = instr.immediate.integer;
				break;
			case SCAD_MOVE_INVALID:
#ifdef EMULATOR
				printf("control: SCAD_MOVE_INVALID\n");
#endif
				pc = -1;
			default:
#ifdef EMULATOR
				printf("control: UNKOWN OPCODE! %d\n", instr.op);
#endif
				pc = -1;
		}
	}
	
	// Set in the device description as for example:
	// <parameter><key>SYNC_TO</key><value>{1,2}</value></parameter>
	struct scad_buffer_address sync_units[] = {${SYNC_TO}};
	#pragma unroll
	for(int i = 0; sync_units[i].unit; i++) {
		send_move_sync(sync_units[i]);
	}
}

