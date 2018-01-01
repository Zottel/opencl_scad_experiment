#ifndef SCAD_CONFIG_CL
#define SCAD_CONFIG_CL

// Depth of reordering buffers.
#define  BUFFER_DEPTH ${BUFFER_DEPTH}

// Number of functional units to allocate endpoints for
#define  UNIT_COUNT ${UNIT_COUNT}

// Altera channel depth (different from buffer size).
// TODO: With the trivial interconnect, emulation hangs for depth of 1,
//       but this should not be the case for hardware synthesis
//       -> invesitage when we have access to hardware.
#define  CHANNEL_DEPTH 1

#endif /* SCAD_CONFIG_CL */
