#ifndef SCAD_CHANNELS_CL
#define SCAD_CHANNELS_CL

#pragma OPENCL EXTENSION cl_altera_channels : enable

#if AOC_VERSION == 17
	// workaround for intels channel function rename:
	#define write_channel_altera    write_channel_intel
	#define write_channel_nb_altera write_channel_nb_intel
	#define read_channel_altera     read_channel_intel
	#define read_channel_nb_altera  read_channel_nb_intel
#endif


#include "config.cl"

#include "common/instructions.h"

// Global channels connecting parts

// These two are unbuffered because the have very critical
// and immediate data dependencies.
//channel struct scad_instruction channel_move_instructions_to[UNIT_COUNT]
//	__attribute__((depth(CHANNEL_DEPTH)));
//channel bool channel_move_instructions_to_ack[UNIT_COUNT]
//	__attribute__((depth(1)));
channel struct scad_instruction channel_move_instructions_to[UNIT_COUNT];
channel bool channel_move_instructions_to_ack[UNIT_COUNT];


channel struct scad_instruction channel_move_instructions_from[UNIT_COUNT]
	__attribute__((depth(CHANNEL_DEPTH)));

channel struct scad_data_packet channel_to_interconnect[UNIT_COUNT]
	__attribute__((depth(CHANNEL_DEPTH)));

channel struct scad_data_packet channel_from_interconnect[UNIT_COUNT]
	__attribute__((depth(CHANNEL_DEPTH)));

#endif /* SCAD_CHANNELS_CL */
