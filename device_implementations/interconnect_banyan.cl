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

#define BANYAN_SIZE 2
#define BANYAN_DEPTH 1

#elif UNIT_COUNT <= 4

#define BANYAN_SIZE 4
#define BANYAN_DEPTH 2

#elif UNIT_COUNT <= 8

#define BANYAN_SIZE 8
#define BANYAN_DEPTH 3

#elif UNIT_COUNT <= 16

#define BANYAN_SIZE 16
#define BANYAN_DEPTH 4

#elif UNIT_COUNT <= 32

#define BANYAN_SIZE 32
#define BANYAN_DEPTH 5

#elif UNIT_COUNT <= 64

#define BANYAN_SIZE 64
#define BANYAN_DEPTH 6

#elif UNIT_COUNT <= 128

#define BANYAN_SIZE 128
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
                    __private struct scad_data_packet_nb * restrict in0,
                    __private struct scad_data_packet_nb * restrict in1,
                    __private struct scad_data_packet_nb * restrict out0,
                    __private struct scad_data_packet_nb * restrict out1) {
	if(!out0->valid) {
		if(in0->valid && (in0->packet.to.unit & (1 << addr_bit))) {
			*out0 = *in0;
			in0->valid = false;
#ifdef EMULATOR
			printf("Interconnect: internally moved a packet.\n");
#endif
		} else if(in1->valid && (in1->packet.to.unit & (1 << addr_bit))) {
			*out0 = *in1;
			in1->valid = false;
#ifdef EMULATOR
			printf("Interconnect: internally moved a packet.\n");
#endif
		}
	}
	
	if(!out1->valid) {
		if(in0->valid && !(in0->packet.to.unit & (1 << addr_bit))) {
			*out1 = *in0;
			in0->valid = false;
#ifdef EMULATOR
			printf("Interconnect: internally moved a packet.\n");
#endif
		} else if(in1->valid && !(in1->packet.to.unit & (1 << addr_bit))) {
			*out1 = *in1;
			in1->valid = false;
#ifdef EMULATOR
			printf("Interconnect: internally moved a packet.\n");
#endif
		}
	}
}

__attribute__((max_global_work_dim(0)))
__attribute__((autorun))
kernel void ${NAME}() {
	
	// Matrix of registers before, inside and after banyan network.
	// Todo: These are translated to memory - which is not a viable result.
	#define COL(X) (BANYAN_SIZE * X)
	#define ROW(Y) (Y)
	__private __attribute__((register)) struct scad_data_packet_nb buffers[BANYAN_SIZE * (BANYAN_DEPTH+1)];
	
	while(1) {
		// INPUT:
		// Read values into empty buffers
		#pragma ivdep
		#pragma unroll
		for(int i = 0; i < BANYAN_SIZE; i++) {
			if(!buffers[COL(0) + ROW(i)].valid) {
				buffers[COL(0) + ROW(i)].packet = read_channel_nb_altera(channel_to_interconnect[i], &buffers[COL(0) + ROW(i)].valid);
	#ifdef EMULATOR
				if(buffers[COL(0) + ROW(i)].valid) {
					struct scad_data_packet packet = buffers[COL(0) + ROW(i)].packet;
					printf("Interconnect received: %d.%d -> %d.%d\n",
								 packet.from.unit, packet.from.buffer,
								 packet.to.unit, packet.to.buffer);
				}
	#endif
			}
		}
		
		// NETWORK
		for(int column = 0; column < BANYAN_DEPTH; column++) {
			#pragma ivdep
			#pragma unroll
			for(int i = 0; i < (BANYAN_SIZE / 2); i++) {
				${NAME}_switch((BANYAN_DEPTH - column),
				               &buffers[COL(column) + ROW(i)],
				               &buffers[COL(column) + ROW(i+1)],
				               &buffers[COL(column + 1) + ROW(${NAME}_permutation((BANYAN_DEPTH - column), i))],
				               &buffers[COL(column + 1) + ROW(${NAME}_permutation((BANYAN_DEPTH - column), i+1))]);
			}
		}
		
		// OUTPUT
		#pragma ivdep
		#pragma unroll
		for(int i = 0; i < BANYAN_SIZE; i++) {
			if(buffers[COL(BANYAN_DEPTH) + ROW(i)].valid) {
	#ifdef EMULATOR
				//printf("Interconnect attempting delivery at port %d.\n", fst);
	#endif
				buffers[COL(BANYAN_DEPTH) + ROW(i)].valid =
					!write_channel_nb_altera(channel_from_interconnect[i],
					                         buffers[COL(BANYAN_DEPTH) + ROW(i)].packet);
				if(!buffers[COL(BANYAN_DEPTH) + ROW(i)].valid) {
	#ifdef EMULATOR
					struct scad_data_packet packet = buffers[COL(BANYAN_DEPTH) + ROW(i)].packet;
					printf("Interconnect delivered %d.%d -> %d.%d at port %d.\n",
					       packet.from.unit, packet.from.buffer,
					       packet.to.unit, packet.to.buffer,
					       i);
	#endif
				}
			}
		}
	}
}
