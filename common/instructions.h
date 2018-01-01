#ifndef SCAD_INSTRUCTIONS_H
#define SCAD_INSTRUCTIONS_H

// Declarations to make header file usable from both C++ and OpenCL
#if defined(ALTERA_CL)

// Type adaptions because cl_* types are not natively available in OpenCL
#define cl_uchar unsigned char
#define cl_uint uint
#define cl_ulong ulong
#define cl_double double

#else /* Not ALTERA_CL */
#ifdef __cplusplus
#define CL_USE_DEPRECATED_OPENCL_1_2_APIS
#define __CL_ENABLE_EXCEPTIONS
#include <CL/cl.hpp>
namespace scad {
#endif /* C++ */

#endif /* ALTERA_CL */

typedef union {
	cl_ulong integer;
	cl_double floating_point;
	struct {
		cl_uint opcode;
		cl_uint count;
	} op;
} scad_data;

enum scad_opcodes {
	SCAD_MOVE_INVALID = 0,
	SCAD_MOVE = 1,
	SCAD_MOVE_IMMEDIATE = 2,
	SCAD_MOVE_PC = 3,
};

enum scad_lsu_opcode {
	SCAD_LSU_INVALID = 0,
	SCAD_LSU_LOAD = 1,
	SCAD_LSU_STORE = 2,
};

enum scad_pu_opcode {
	SCAD_PU_INVALID = 0,
	SCAD_PU_ADDN = 1,
	SCAD_PU_SUBN = 2,
	SCAD_PU_MULN = 3,
	SCAD_PU_DIVN = 4,
	SCAD_PU_MODN = 5,
	SCAD_PU_LESN = 6,
	SCAD_PU_LEQN = 7,
	SCAD_PU_EQQN = 8,
	SCAD_PU_NEQN = 9,
	SCAD_PU_ADDZ = 10,
	SCAD_PU_SUBZ = 11,
	SCAD_PU_MULZ = 12,
	SCAD_PU_DIVZ = 13,
	SCAD_PU_MODZ = 14,
	SCAD_PU_LESZ = 15,
	SCAD_PU_LEQZ = 16,
	SCAD_PU_EQQZ = 17,
	SCAD_PU_NEQZ = 18,
	SCAD_PU_ANDB = 19,
	SCAD_PU_ORB  = 20,
	SCAD_PU_EQQB = 21,
	SCAD_PU_NEQB = 22,
};

struct __attribute__((packed)) scad_buffer_address {
	cl_uchar unit, buffer;
};

struct __attribute__((packed)) scad_instruction {
	enum scad_opcodes op;
	
	union __attribute__ ((packed)) {
		struct scad_buffer_address from;
		
		scad_data immediate;
	};
	
	struct scad_buffer_address to;
};

struct __attribute__((packed)) scad_data_packet {
	
	scad_data data;
	
	struct scad_buffer_address from;
	
	struct scad_buffer_address to;
};

struct __attribute__((packed)) scad_data_packet_nb {
	bool valid;
	
	struct scad_data_packet packet;
};


#ifdef __cplusplus
} // namespace scad
#endif /* __cplusplus */

#endif /* SCAD_INSTRUCTIONS_H */

