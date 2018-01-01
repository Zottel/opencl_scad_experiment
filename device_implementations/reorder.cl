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
#include "buffer.cl"

#define SCAD_REORDER_INPUT_NUM 1

__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
kernel void ${NAME}() {
#ifdef EMULATOR
	printf("[reorder] starting with id %d and %d input buffers\n", ${NUMBER}, SCAD_REORDER_INPUT_NUM);
#endif
	__attribute__((register)) struct scad_buffer_input input[SCAD_REORDER_INPUT_NUM];
	__attribute__((register)) struct scad_buffer_management input_manage =
		scad_input_init(${NUMBER}, SCAD_REORDER_INPUT_NUM, input);
	
	__attribute__((register)) struct scad_buffer_output output[SCAD_REORDER_INPUT_NUM];
	__attribute__((register)) struct scad_buffer_management output_manage =
		scad_output_init(${NUMBER}, SCAD_REORDER_INPUT_NUM, output);
	
	while(true) {
		scad_output_handle(${NUMBER}, &output_manage, output);
		
		for(int i = 0; i < SCAD_REORDER_INPUT_NUM; i++) {
			if(buffer_input_has_data(&input[i])
			   && !buffer_output_data_full(&output[i])) {
				scad_data value = buffer_input_pop(&input[i]);
				buffer_output_push_data(&output[i], value);
#ifdef EMULATOR
				printf("[reorder] buffer %d fired 0x%lx\n", i, value.integer);
#endif
			}
		}
		
		scad_input_handle(${NUMBER}, &input_manage, input);
	}
}

