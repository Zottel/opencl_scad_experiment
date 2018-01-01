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

/* PROCESSING UNIT
 * INPUTS: in0 (left operand), in1 (right operand), opc (opcode, count)
 * OUTPUT: out (result)
 */


#include "common/instructions.h"

#include "channels.cl"
#include "buffer.h"

scad_data ${NAME}_eval(scad_data left, scad_data right, enum scad_pu_opcode opcode) {
	switch(opcode) {
		case SCAD_PU_ADDN:
			return (scad_data) {.integer = (left.integer + right.integer)};
		case SCAD_PU_SUBN:
			return (scad_data) {.integer = (left.integer - right.integer)};
		case SCAD_PU_MULN:
			return (scad_data) {.integer = (left.integer * right.integer)};
		case SCAD_PU_DIVN:
			return (scad_data) {.integer = (left.integer / right.integer)};
		case SCAD_PU_MODN:
			return (scad_data) {.integer = (left.integer % right.integer)};
		case SCAD_PU_LESN:
			return (scad_data) {.integer = (left.integer < right.integer)};
		case SCAD_PU_LEQN:
			return (scad_data) {.integer = (left.integer <= right.integer)};
		case SCAD_PU_EQQN:
			return (scad_data) {.integer = (left.integer == right.integer)};
		case SCAD_PU_NEQN:
			return (scad_data) {.integer = (left.integer != right.integer)};
		
		case SCAD_PU_ADDZ:
			return (scad_data) {.integer = (unsigned long) (((long) left.integer) + ((long) right.integer))};
		case SCAD_PU_SUBZ:
			return (scad_data) {.integer = (unsigned long) (((long) left.integer) - ((long) right.integer))};
		case SCAD_PU_MULZ:
			return (scad_data) {.integer = (unsigned long) (((long) left.integer) * ((long) right.integer))};
		case SCAD_PU_DIVZ:
			return (scad_data) {.integer = (unsigned long) (((long) left.integer) / ((long) right.integer))};
		case SCAD_PU_MODZ:
			return (scad_data) {.integer = (unsigned long) (((long) left.integer) % ((long) right.integer))};
		case SCAD_PU_LESZ:
			return (scad_data) {.integer = (unsigned long) (((long) left.integer) < ((long) right.integer))};
		case SCAD_PU_LEQZ:
			return (scad_data) {.integer = (unsigned long) (((long) left.integer) <= ((long) right.integer))};
		case SCAD_PU_EQQZ:
			return (scad_data) {.integer = (unsigned long) (((long) left.integer) == ((long) right.integer))};
		case SCAD_PU_NEQZ:
			return (scad_data) {.integer = (unsigned long) (((long) left.integer) != ((long) right.integer))};
		
		case SCAD_PU_ANDB:
			return (scad_data) {.integer = (left.integer & right.integer)};
		case SCAD_PU_ORB:
			return (scad_data) {.integer = (left.integer | right.integer)};
		case SCAD_PU_EQQB:
			return (scad_data) {.integer = ~(left.integer ^ right.integer)};
		case SCAD_PU_NEQB:
			return (scad_data) {.integer = (left.integer ^ right.integer)};
		
		case SCAD_PU_INVALID:
#ifdef EMULATOR
			printf("[processing]: ERROR: INVALID OPCODE!");
#endif
			break;
		
		default:
#ifdef EMULATOR
			printf("[processing]: ERROR: UNKNOWN OPCODE!");
#endif
			break;
	}
	
	return (scad_data) {.integer = -1};
}

// LSU
// 3 inputs: in0, in1, opc
#define SCAD_LSU_INPUT_NUM 3
// 1 output: out
#define SCAD_LSU_OUTPUT_NUM 1
__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
kernel void ${NAME}() {
#ifdef EMULATOR
	printf("[processing] unit starting with id %d\n", ${NUMBER});
#endif
	__attribute__((register)) struct scad_buffer_input input[SCAD_LSU_INPUT_NUM];
	__attribute__((register)) struct scad_buffer_management input_manage =
		scad_input_init(${NUMBER}, SCAD_LSU_INPUT_NUM, input);
	
	__attribute__((register)) struct scad_buffer_output output[SCAD_LSU_OUTPUT_NUM];
	__attribute__((register)) struct scad_buffer_management output_manage =
		scad_output_init(${NUMBER}, SCAD_LSU_OUTPUT_NUM, output);
	
	// Result copies that still need to be stored in the output buffer.
	scad_data pending_data;
	cl_uchar pending_copies = 0;
	
	while(1) {
		// Handle receiving data.
		scad_input_handle(${NUMBER}, &input_manage, input);
		
		// No more pending copies and all inputs are available
		// Execute next operation
		if(pending_copies == 0
		   && buffer_input_has_data(&input[0])
		   && buffer_input_has_data(&input[1])
		   && buffer_input_has_data(&input[2])) {
			
			// Get parameters.
			scad_data left_operand = buffer_input_pop(&input[0]); // lsu.in0
			scad_data right_operand = buffer_input_pop(&input[1]); // lsu.in1
			scad_data opc = buffer_input_pop(&input[2]); // lsu.opc
			
			// Perform calculation.
			pending_data = ${NAME}_eval(left_operand, right_operand, opc.op.opcode);
			pending_copies = opc.op.count;
			
#ifdef EMULATOR
			printf("[processing](%d): 0x%x(0x%lx, 0x%lx) = 0x%lx (0x%x copies)\n",
			       ${NUMBER},
			       opc.op.opcode,
			       right_operand.integer,
			       left_operand.integer,
			       pending_data.integer,
			       opc.op.count);
#endif
		}
		
		// Copy pending data to output buffer if there is space available.
		while(pending_copies > 0 && !buffer_output_data_full(&output[0])) {
			//printf("[processing]: pushing data to output: 0x%x (0x%lx copies remaining).\n", pending_data.integer, pending_copies);
			buffer_output_push_data(&output[0], pending_data);
			pending_copies--;
			//printf("[processing]: state of lsu.out: (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
			//      output[0].to_full, output[0].data_full, output[0].start, output[0].to_end, output[0].data_end);
		}
		
		// Buffer send handling.
		scad_output_handle(${NUMBER}, &output_manage, output);
		//printf("[processing]: post-handling: state of lsu.out: (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
		//      output[0].to_full, output[0].data_full, output[0].start, output[0].to_end, output[0].data_end);
	}
}

