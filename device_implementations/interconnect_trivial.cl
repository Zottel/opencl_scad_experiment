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
#include "config.cl"
#include "channels.cl"


// Hack to use dynamic channel indices.
struct scad_data_packet ${NAME}_input(cl_uchar unit, bool *value_read) {
	struct scad_data_packet packet = {.data={.integer = -1}, .from={-1, -1}, .to={-1, -1}};
	*value_read = false;
	
	#pragma unroll
	for (int i = 0; i < UNIT_COUNT; i++) {
		if(unit == i) {
			packet = read_channel_nb_altera(channel_to_interconnect[i], value_read);
		}
	}
	return packet;
}

void ${NAME}_output(cl_uchar unit, struct scad_data_packet packet) {
	#pragma unroll
	for (int i = 0; i < UNIT_COUNT; i++) {
		if(unit == i) {
			write_channel_altera(channel_from_interconnect[i], packet);
		}
	}
}

__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
__kernel void ${NAME}() {
#ifdef EMULATOR
	printf("interconnect starting.\n");
#endif
	while(1) {
		for(unsigned int from = 0;; from = (from + 1) % UNIT_COUNT) {
			bool read_from;
			struct scad_data_packet packet = ${NAME}_input(from, &read_from);
			
			if(read_from) {
#ifdef EMULATOR
				printf("interconnect: transmitting data packet from %d.%d -> %d.%d: $0x%lx\n",
				       packet.from.unit, packet.from.buffer, packet.to.unit, packet.to.buffer,
				       packet.data.integer);
#endif
				if(packet.to.unit < UNIT_COUNT) {
					${NAME}_output(packet.to.unit, packet);
				} else {
#ifdef EMULATOR
				printf("interconnect: INVALID DESTINATION: %d.%d -> %d.%d: $0x%lx\n",
				       packet.from.unit, packet.from.buffer, packet.to.unit, packet.to.buffer,
				       packet.data.integer);
#endif
				}
			}
		}
	}
}
