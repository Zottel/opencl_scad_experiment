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

#include "channels.h"
#include "buffer.h"

#define SCAD_DUMMY_ID 127
#define SCAD_DUMMY_INPUT_NUM 8

__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
__kernel void scad_dummy() {
#ifdef EMULATOR
	printf("dummy: starting with id %d and %d input buffers\n", SCAD_DUMMY_ID, SCAD_DUMMY_INPUT_NUM);
#endif
	struct scad_buffer_input input[SCAD_DUMMY_INPUT_NUM];
	struct scad_buffer_management input_manage =
		scad_input_init(SCAD_DUMMY_ID, SCAD_DUMMY_INPUT_NUM, input);
	
	while(true) {
		// Handle receiving data.
		scad_input_handle(SCAD_DUMMY_ID, &input_manage, input);
		
		for(int i = 0; i < SCAD_DUMMY_INPUT_NUM; i++) {
			if(buffer_input_has_data(&input[i])) {
#ifdef EMULATOR
				printf("dummy: input buffer %d produced: 0x%lx\n", i, buffer_input_pop(&input[i]));
#else
				buffer_input_pop(&input[i]);
#endif
			}
		}
	}
}
