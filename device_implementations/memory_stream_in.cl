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

// Reads data from given memory into its output buffer.

__kernel void ${NAME}(__global scad_data * restrict mem_in,
                      cl_uint mem_in_length) {
	
#ifdef EMULATOR
	printf("memory stream input starting with id %d\n", ${NUMBER});
#endif
	
	// One output buffer.
	struct scad_buffer_management output_manage;
	struct scad_buffer_output output[1];
	scad_output_init(${NUMBER}, 1, &output_manage, output);
	
	cl_ulong index = 0;
	
	while(index < mem_in_length) {
		if(!buffer_output_data_full(&output[0])) {
			buffer_output_push_data(&output[0], mem_in[index++]);
		}
		
		scad_output_handle(${NUMBER}, &output_manage, output);
	}
}

