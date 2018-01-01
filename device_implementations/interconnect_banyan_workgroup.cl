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

// 1 is just wrong.
#if UNIT_COUNT == 2

#define BANYAN_WORK_ITEMS 1
#define BANYAN_DEPTH 1

#elif UNIT_COUNT <= 4

#define BANYAN_WORK_ITEMS 2
#define BANYAN_DEPTH 2

#elif UNIT_COUNT <= 8

#define BANYAN_WORK_ITEMS 8
#define BANYAN_DEPTH 3

#elif UNIT_COUNT <= 16

#define BANYAN_WORK_ITEMS 8
#define BANYAN_DEPTH 4

#elif UNIT_COUNT <= 32

#define BANYAN_WORK_ITEMS 16
#define BANYAN_DEPTH 5

#elif UNIT_COUNT <= 64

#define BANYAN_WORK_ITEMS 32
#define BANYAN_DEPTH 6

#elif UNIT_COUNT <= 128

#define BANYAN_WORK_ITEMS 64
#define BANYAN_DEPTH 7

#else
#error UNIT_COUNT is not a supported number (valid: 128, 64, 32, 16, 8, 4)
#endif

int ${NAME}_permutation(int size_exponent, int i) {
	// This is a no-op for size_exponent=0, which the compiler should(?) detect.
	
	// remove bits to swap
	int res = i & ~(1 + (1 << size_exponent));
	
	// res[0] = i[size_exponent]
	res |= (i & (1 << size_exponent)) >> size_exponent;
	// res[size_exponent] = i[0]
	res |= (i & 1) << size_exponent;
	
	return res;
}

void ${NAME}_switch(int addr_bit,
                    __local struct scad_data_packet_nb *in0,
                    __local struct scad_data_packet_nb *in1,
                    __local struct scad_data_packet_nb *out0,
                    __local struct scad_data_packet_nb *out1) {
	if(!out0->valid) {
		if(in0->valid && !(in0->packet.to.unit & (1 << addr_bit))) {
			*out0 = *in0;
			in0->valid = false;
#ifdef EMULATOR
			printf("Interconnect: internally moved a packet straigth in upper switch lane. (addr_bit: %d).\n", addr_bit);
#endif
		} else if(in1->valid && !(in1->packet.to.unit & (1 << addr_bit))) {
			*out0 = *in1;
			in1->valid = false;
#ifdef EMULATOR
			printf("Interconnect: internally moved a packet from lane 1 to 0 in a switch. (addr_bit: %d).\n", addr_bit);
#endif
		}
	}
	
	if(!out1->valid) {
		if(in0->valid && (in0->packet.to.unit & (1 << addr_bit))) {
			*out1 = *in0;
			in0->valid = false;
			printf("Interconnect: internally moved a packet from lane 0 to 1 in a switch. (addr_bit: %d).\n", addr_bit);
		} else if(in1->valid && (in1->packet.to.unit & (1 << addr_bit))) {
			*out1 = *in1;
			in1->valid = false;
			printf("Interconnect: internally moved a packet straigth in lower switch lane. (addr_bit: %d).\n", addr_bit);
		}
	}
}

// The emulator does not recognize workgroups and autorun together.
__attribute__((reqd_work_group_size(BANYAN_WORK_ITEMS, 1, 1)))
__attribute__((max_work_group_size(BANYAN_WORK_ITEMS)))
//__attribute__((autorun))
kernel void ${NAME}() {
	
	//size_t gid = get_global_id(0);
	size_t gid = get_local_id(0);
	
	printf("banyan (units: %d, workitems: %d (actual local size: %lu), depth: %d) interconnect worker %lu starting.\n",
	       UNIT_COUNT, BANYAN_WORK_ITEMS, get_local_size(0), BANYAN_DEPTH,
	       gid);
	
	// Matrix of buffers before, inside and after banyan network.
	__local struct scad_data_packet_nb buffers[BANYAN_WORK_ITEMS][BANYAN_DEPTH+1];
	
	// Each work item has one row of switches,
	// which translates to two inputs and outputs each per column.
	size_t fst = gid * 2;     // first data row index
	size_t snd = gid * 2 + 1; // second data row index
	
	while(1) {
		// INPUT:
		// Read values into empty buffers
		if(!buffers[fst][0].valid) {
			buffers[fst][0].packet = read_channel_nb_altera(channel_to_interconnect[fst], &buffers[fst][0].valid);
			if(buffers[fst][0].valid) {
				struct scad_data_packet packet = buffers[fst][0].packet;
				printf("Interconnect received: %d.%d -> %d.%d\n",
				       packet.from.unit, packet.from.buffer,
				       packet.to.unit, packet.to.buffer);
			}
		}
		if(!buffers[snd][0].valid) {
			buffers[snd][0].packet = read_channel_nb_altera(channel_to_interconnect[snd], &buffers[snd][0].valid);
			if(buffers[snd][0].valid) {
				struct scad_data_packet packet = buffers[snd][0].packet;
				printf("Interconnect received: %d.%d -> %d.%d\n",
				       packet.from.unit, packet.from.buffer,
				       packet.to.unit, packet.to.buffer);
			}
		}
		
		// NETWORK
		#pragma unroll
		for(__private int i = 0; i < BANYAN_DEPTH; i++) {
			// I do the permutation first since this makes the indices easiest to handle.
			${NAME}_switch((BANYAN_DEPTH - i),
			               &buffers[fst][i],
			               &buffers[snd][i],
			               &buffers[${NAME}_permutation((BANYAN_DEPTH - i), fst)][i+1],
			               &buffers[${NAME}_permutation((BANYAN_DEPTH - i), snd)][i+1]);
			
			barrier(CLK_LOCAL_MEM_FENCE);
		}
		
		// OUTPUT
		if(buffers[fst][BANYAN_DEPTH].valid) {
			//printf("Interconnect attemplting delivery at port %d.\n", fst);
			buffers[fst][BANYAN_DEPTH].valid =
				!write_channel_nb_altera(channel_from_interconnect[fst],
				                         buffers[fst][BANYAN_DEPTH].packet);
			if(!buffers[fst][BANYAN_DEPTH].valid) {
				struct scad_data_packet packet = buffers[fst][BANYAN_DEPTH].packet;
				printf("Interconnect delivered %d.%d -> %d.%d at port %lu.\n",
				       packet.from.unit, packet.from.buffer,
				       packet.to.unit, packet.to.buffer,
				       fst);
			}
		}
		if(buffers[snd][BANYAN_DEPTH].valid) {
			//printf("Interconnect attemplting delivery at port %d.\n", snd);
			buffers[snd][BANYAN_DEPTH].valid =
				!write_channel_nb_altera(channel_from_interconnect[snd],
				                         buffers[snd][BANYAN_DEPTH].packet);
			if(!buffers[snd][BANYAN_DEPTH].valid) {
				struct scad_data_packet packet = buffers[snd][BANYAN_DEPTH].packet;
				printf("Interconnect delivered %d.%d -> %d.%d at port %lu.\n",
				       packet.from.unit, packet.from.buffer,
				       packet.to.unit, packet.to.buffer,
				       snd);
			}
		}
	}
}
