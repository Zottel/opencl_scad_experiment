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
#include "buffer.h"

// Stores all data it receives from the interconnect into the given memory.

__kernel void ${NAME}(write_only __global scad_data * restrict mem_out,
                      read_only cl_uint mem_out_length) {
	
#ifdef EMULATOR
	printf("memory stream output starting with id %d\n", ${NUMBER});
#endif
	
	// One input buffer.
	struct scad_buffer_management input_manage;
	struct scad_buffer_input input[1];
	scad_input_init(${NUMBER}, 1, &input_manage, input);
	
	cl_ulong index = 0;
	
	while(index < mem_in_length) {
		scad_input_handle(${NUMBER}, &input_manage, input);
		
		if(buffer_input_has_data(&input[0])) {
			mem_out[index++] = buffer_input_pop(&input[0]);
		}
	}
}

