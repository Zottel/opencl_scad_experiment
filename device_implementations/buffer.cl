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

#ifndef SCAD_BUFFER_CL
#define SCAD_BUFFER_CL

#include "channels.cl"
#include "buffer.h"

/******************************************************************************
 * INPUT                                                                      *
 ******************************************************************************/

void buffer_input_dump(struct scad_buffer_input *buffer) {
#ifdef EMULATOR
	printf("buffer %p: full(%d) start(%d), end(%d) data(", buffer, buffer->from_full, buffer->start, buffer->end);
	for(int i = 0; i < INPUT_BUFFER_DEPTH; i++) {
		printf(" %d ", buffer->data_set[i]);
	}
	printf(")\n");
#endif
}

void buffer_input_init(struct scad_buffer_input *buffer) {
	buffer->from_full = false;
	buffer->start = 0;
	buffer->end = 0;
}

bool buffer_input_full(struct scad_buffer_input *buffer) {
	return buffer->from_full;
}

// Assumption: buffer_input_full(...) returned false.
void buffer_input_push_from(struct scad_buffer_input *buffer, struct scad_buffer_address from) {
#ifdef EMULATOR
	printf("buffer: starting buffer_input_push_from()\n");
#endif
	buffer->from[buffer->end] = from;
	// Input messages with reserved address sender are for synchronization only.
	if(buffer_address_is_reserved(from)) {
		buffer->data_set[buffer->end] = true;
	} else {
		buffer->data_set[buffer->end] = false;
	}
	
	//buffer->end = (buffer->end + 1) % INPUT_BUFFER_DEPTH;
	buffer->end = (buffer->end + 1);
	if (buffer->end == INPUT_BUFFER_DEPTH) {
		buffer->end = 0;
	}
	
	if(buffer->end == buffer->start) {
		buffer->from_full = true;
	}
#ifdef EMULATOR
	printf("buffer: done: buffer_input_push_from()\n");
#endif
}

// Assumption: data always arrives after move instruction!
void buffer_input_push_data(struct scad_buffer_input *buffer, struct scad_data_packet packet) {
	int current = buffer->start;
	
	// special case for full buffer
	if(buffer->from_full) {
		if(buffer->from[current].unit == packet.from.unit
		   && buffer->from[current].buffer == packet.from.buffer
		   && !(buffer->data_set[current])) {
			buffer->data[current] = packet.data;
			buffer->data_set[current] = true;
			return;
		}
		
		//current = (current + 1) % INPUT_BUFFER_DEPTH;
		current = (current + 1);
		if(current == INPUT_BUFFER_DEPTH) {
			current = 0;
		}
	}
	
	while(current != buffer->end) {
		if(buffer->from[current].unit == packet.from.unit
		   && buffer->from[current].buffer == packet.from.buffer
		   && !(buffer->data_set[current])) {
			buffer->data[current] = packet.data;
			buffer->data_set[current] = true;
			return;
		}
		
		//current = (current + 1) % INPUT_BUFFER_DEPTH;
		current = (current + 1);
		
		if(current == INPUT_BUFFER_DEPTH) {
			current = 0;
		}
	}
}

bool buffer_input_has_data(struct scad_buffer_input *buffer) {
	// Incoming moves existing?
	if(buffer->end != buffer->start || buffer->from_full) {
		// Data available?
		return buffer->data_set[buffer->start];
	} else {
		// Not even one incoming move pending.
		return false;
	}
}

bool buffer_input_has_marker(struct scad_buffer_input *buffer) {
	return buffer_input_has_data(buffer)
	       && buffer_address_is_reserved(buffer->from[buffer->start]);
}

// Assumption: buffer_input_has_data(...) returned true.
scad_data buffer_input_pop(struct scad_buffer_input *buffer) {
	if(buffer->start == buffer->end) {
		buffer->from_full = false;
	}
	
	int current_start = buffer->start;
	
	//buffer->start = (buffer->start + 1) % INPUT_BUFFER_DEPTH;
	buffer->start = (buffer->start + 1);
	if(buffer->start == INPUT_BUFFER_DEPTH) {
		buffer->start = 0;
	}
	
	return buffer->data[current_start];
}

// Useful in conjunction with nonblocking channels
scad_data buffer_input_peek(struct scad_buffer_input *buffer) {
	return buffer->data[buffer->start];
}


/******************************************************************************
 * OUTPUT                                                                     *
 ******************************************************************************/

// Output buffer consists of two ring buffers with a shared start.
// Pushes to this buffer are mostly independent, popping ready messages are not.

void buffer_output_init(struct scad_buffer_output *buffer) {
	buffer->to_full = false;
	buffer->data_full = false;
	buffer->start = 0;
	buffer->to_end = 0;
	buffer->data_end = 0;
}

bool buffer_output_data_empty(struct scad_buffer_output *buffer) {
	return (buffer->start == buffer->data_end)
	        && !buffer->data_full;
}

bool buffer_output_data_full(struct scad_buffer_output *buffer) {
	return buffer->data_full;
}

bool buffer_output_to_full(struct scad_buffer_output *buffer) {
	return buffer->to_full;
}

// Assumption: buffer_output_data_full
void buffer_output_push_data(struct scad_buffer_output *buffer, scad_data data) {
	buffer->data[buffer->data_end] = data;
	//buffer->data_end = (buffer->data_end + 1) % OUTPUT_BUFFER_DEPTH;
	buffer->data_end = (buffer->data_end + 1);
	if(buffer->data_end == OUTPUT_BUFFER_DEPTH) {
		buffer->data_end = 0;
	}
	
#ifdef EMULATOR
	//printf("buffer: state (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
	//       buffer->to_full, buffer->data_full, buffer->start, buffer->to_end, buffer->data_end);
#endif
	
	if(buffer->data_end == buffer->start) {
		buffer->data_full = true;
	}
}

void buffer_output_push_to(struct scad_buffer_output *buffer,
                           struct scad_buffer_address to) {
	buffer->to[buffer->to_end] = to;
	//buffer->to_end = (buffer->to_end + 1) % OUTPUT_BUFFER_DEPTH;
	buffer->to_end = (buffer->to_end + 1);
	if(buffer->to_end == OUTPUT_BUFFER_DEPTH) {
		buffer->to_end = 0;
	}
	
	if(buffer->to_end == buffer->start) {
		buffer->to_full = true;
	}
}

bool buffer_output_has_packet(struct scad_buffer_output *buffer) {
	return (buffer->to_full || buffer->start != buffer->to_end)
	        && (buffer->data_full || buffer->start != buffer->data_end);
}

// to_send = buffer_output_pop(&output, (struct scad_buffer_address) {x,y})
struct scad_data_packet buffer_output_pop(struct scad_buffer_output *buffer,
                                          struct scad_buffer_address from) {
	int current_start = buffer->start;
	
	//buffer->start = (buffer->start + 1) % OUTPUT_BUFFER_DEPTH;
	buffer->start = (buffer->start + 1);
	if(buffer->start == OUTPUT_BUFFER_DEPTH) {
		buffer->start = 0;
	}
	buffer->to_full = false; buffer->data_full = false;
	return (struct scad_data_packet) {
		.to = buffer->to[current_start],
		.from = from,
		.data = buffer->data[current_start],
	};
}

/******************************************************************************
 * ABSTRACTED CHANNEL AND BUFFER HANDLING                                     *
 ******************************************************************************/

struct scad_buffer_management scad_input_init(cl_uchar unit, cl_uchar buff_count,
                                              struct scad_buffer_input *buff) {
	struct scad_buffer_management man_result = {
		.unit = unit, .buff_count = buff_count,
		.pending_valid = false
	};
	for(int i = 0; i < buff_count; i++) {
		buffer_input_init(&buff[i]);
	}
	return man_result;
}

void scad_input_handle(cl_uchar unit,
                       struct scad_buffer_management *man,
                       struct scad_buffer_input buff[]){
	if(!man->pending_valid) {
		man->pending = read_channel_nb_altera(channel_move_instructions_to[unit], &man->pending_valid);
		if(man->pending_valid) {
#ifdef EMULATOR
			printf("input buffer sending ack for received: %d.%d -> %d.%d\n",
			       man->pending.from.unit, man->pending.from.buffer,
			       man->pending.to.unit, man->pending.to.buffer);
#endif
		}
	}
	
	if(man->pending_valid) {
		if(!buffer_input_full(&buff[man->pending.to.buffer])) {
			buffer_input_push_from(&buff[man->pending.to.buffer], man->pending.from);
			mem_fence(CLK_CHANNEL_MEM_FENCE);
			// Send ACK to control unit.
			write_channel_altera(channel_move_instructions_to_ack[unit], true);
#ifdef EMULATOR
			printf("input buffer sent ack for received: %d.%d -> %d.%d\n",
			       man->pending.from.unit, man->pending.from.buffer,
			       man->pending.to.unit, man->pending.to.buffer);
#endif
			man->pending_valid = false;
		}
	}
	
	bool data_received;
	struct scad_data_packet packet = read_channel_nb_altera(channel_from_interconnect[unit], &data_received);
	if(data_received) {
#ifdef EMULATOR
		printf("input buffer received data! %d.%d -> %d.%d: 0x%lx\n",
		       packet.from.unit, packet.from.buffer,
		       packet.to.unit, packet.to.buffer,
		       packet.data.integer);
#endif
		buffer_input_push_data(&buff[packet.to.buffer], packet);
	}
}

struct scad_buffer_management scad_output_init(cl_uchar unit, cl_uchar buff_count,
                      struct scad_buffer_output *buff) {
	struct scad_buffer_management man_result = {
		.unit = unit, .buff_count = buff_count,
		.pending_valid = false
	};
	//man->unit = unit;
	//man->buff_count = buff_count;
	//man->pending_valid = false;
	for(int i = 0; i < buff_count; i++) {
		buffer_output_init(&buff[i]);
	}
	return man_result;
}

void scad_output_handle(cl_uchar unit,
                        struct scad_buffer_management *man,
                        struct scad_buffer_output buff[]){
	if(!man->pending_valid) {
		man->pending = read_channel_nb_altera(channel_move_instructions_from[unit], &man->pending_valid);
		if(man->pending_valid) {
#ifdef EMULATOR
			printf("buffer: output buffer received move! %d.%d -> %d.%d\n",
			        man->pending.from.unit, man->pending.from.buffer,
			        man->pending.to.unit, man->pending.to.buffer);
#endif
		}
	}
	
	if(man->pending_valid) {
		if(!buffer_output_to_full(&buff[man->pending.from.buffer])) {
			buffer_output_push_to(&buff[man->pending.from.buffer], man->pending.to);
			man->pending_valid = false;
			
			int i = man->pending.from.buffer;
#ifdef EMULATOR
			printf("buffer: state of 0x%x:0x%x: (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
			      man->unit, i, buff[i].to_full, buff[i].data_full, buff[i].start, buff[i].to_end, buff[i].data_end);
#endif
		}
	}
	
	for(int i = 0; i < man->buff_count; i++) {
		if(buffer_output_has_packet(&buff[i])) {
#ifdef EMULATOR
			printf("buffer: output buffer has packet - attempting send!\n");
			
			//printf("buffer: state of 0x%x:0x%x: (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
			//      man->unit, i, buff[i].to_full, buff[i].data_full, buff[i].start, buff[i].to_end, buff[i].data_end);
#endif
			
			struct scad_data_packet packet = buffer_output_pop(&buff[i], (struct scad_buffer_address) { man->unit, i});
			
#ifdef EMULATOR
			//printf("buffer: state of 0x%x:0x%x: (to_full: %d, data_full: %d, start: %d, to_end: %d, data_end: %d)\n",
			//      man->unit, i, buff[i].to_full, buff[i].data_full, buff[i].start, buff[i].to_end, buff[i].data_end);
			
			printf("buffer: output packet: %d.%d -> %d.%d: 0x%lx\n", packet.from.unit, packet.from.buffer,
			       packet.to.unit, packet.to.buffer, packet.data.integer);
#endif
			
			// Messages to reserved address are silently dropped.
			// This is used to delete data.
			if(!buffer_address_is_reserved(packet.to)) {
				write_channel_altera(channel_to_interconnect[unit], packet);
				#ifdef EMULATOR
					printf("buffer: output packet sent: %d.%d -> %d.%d: 0x%lx\n", packet.from.unit, packet.from.buffer,
					       packet.to.unit, packet.to.buffer, packet.data.integer);
				#endif
			}
		}
	}
// output will never be pending o.o
}

#endif /* SCAD_BUFFER_CL */
