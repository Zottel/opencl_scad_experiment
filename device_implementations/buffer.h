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

#ifndef SCAD_BUFFER_H
#define SCAD_BUFFER_H

#include "common/instructions.h"
#include "config.cl"
#include "channels.cl"

/******************************************************************************
 * SETTINGS                                                                   *
 ******************************************************************************/

#define INPUT_BUFFER_DEPTH BUFFER_DEPTH
#define OUTPUT_BUFFER_DEPTH BUFFER_DEPTH

#if INPUT_BUFFER_DEPTH > 255
#error "INPUT BUFFER DEPTH TOO LARGE."
#endif

#if OUTPUT_BUFFER_DEPTH > 255
#error "OUTPUT BUFFER DEPTH TOO LARGE"
#endif

/******************************************************************************
 * COMMON                                                                     *
 ******************************************************************************/

// Special address that is used for synchronisation in input buffers
// and data deletion in output buffers.
#define RESERVED_ADDRESS ((struct scad_buffer_address) \
                         {.unit = (cl_uchar) -1, .buffer = (cl_uchar) -1})
bool buffer_address_is_reserved(struct scad_buffer_address addr) {
	return addr.unit == (cl_uchar) -1
	       && addr.buffer == (cl_uchar) -1;
}

/******************************************************************************
 * INPUT                                                                      *
 ******************************************************************************/

struct scad_buffer_input {
	bool from_full;
	unsigned char start, end;
	
	struct scad_buffer_address from[INPUT_BUFFER_DEPTH];
	scad_data data[INPUT_BUFFER_DEPTH];
	bool data_set[INPUT_BUFFER_DEPTH];
};

void buffer_input_dump(struct scad_buffer_input *buffer);

void buffer_input_init(struct scad_buffer_input *buffer);
bool buffer_input_full(struct scad_buffer_input *buffer);

// Assumption: buffer_inut_full(...) returned false.
void buffer_input_push_from(struct scad_buffer_input *buffer, struct scad_buffer_address from);

// Assumption: data always arrives after move instruction!
void buffer_input_push_data(struct scad_buffer_input *buffer, struct scad_data_packet packet);

bool buffer_input_has_data(struct scad_buffer_input *buffer);
// Special case: if the address is -1@-1 then there will be no data.
// This may be used as a synchronisation marker.
bool buffer_input_has_marker(struct scad_buffer_input *buffer);

// Assumption: buffer_input_has_data(...) returned true.
scad_data buffer_input_pop(struct scad_buffer_input *buffer);

// Useful in conjunction with nonblocking channels
scad_data buffer_input_peek(struct scad_buffer_input *buffer);


/******************************************************************************
 * OUTPUT                                                                     *
 ******************************************************************************/

// Output buffer consists of two ring buffers with a shared start.
// Pushes to this buffer are mostly independent, popping ready messages are not.
struct scad_buffer_output {
	bool to_full;
	bool data_full;
	// Common start, to and data are pushed together
	int start;
	int to_end, data_end;
	
	struct scad_buffer_address to[OUTPUT_BUFFER_DEPTH];
	scad_data data[OUTPUT_BUFFER_DEPTH];
};

void buffer_output_init(struct scad_buffer_output *buffer);

bool buffer_output_data_empty(struct scad_buffer_output *buffer);
bool buffer_output_data_full(struct scad_buffer_output *buffer);

bool buffer_output_to_full(struct scad_buffer_output *buffer);

// Assumption: !buffer_output_data_full
void buffer_output_push_data(struct scad_buffer_output *buffer, scad_data data);

void buffer_output_push_to(struct scad_buffer_output *buffer,
                           struct scad_buffer_address to);

bool buffer_output_has_packet(struct scad_buffer_output *buffer);

// to_send = buffer_output_pop(&output, (struct scad_buffer_address) {x,y})
struct scad_data_packet buffer_output_pop(struct scad_buffer_output *buffer,
                                          struct scad_buffer_address from);


/******************************************************************************
 * ABSTRACTED CHANNEL AND BUFFER HANDLING                                     *
 ******************************************************************************/

// All data stored only once per set of buffers
struct scad_buffer_management {
	cl_uchar unit, buff_count;
	struct scad_instruction pending;
	bool pending_valid;
};

struct scad_buffer_management scad_input_init(cl_uchar unit, cl_uchar buff_count,
                                              struct scad_buffer_input *buff);

void scad_input_handle(cl_uchar unit,
                       struct scad_buffer_management *man,
                       struct scad_buffer_input buff[]);

struct scad_buffer_management scad_output_init(cl_uchar unit, cl_uchar buff_count,
                                               struct scad_buffer_output *buff);

void scad_output_handle(cl_uchar unit,
                        struct scad_buffer_management *man,
                        struct scad_buffer_output buff[]);


#endif /* SCAD_BUFFER_H */
