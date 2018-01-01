
SCAD on FPGA
============

Steps to Compile
----------------

IMPORTANT: There is no proper dependency tracking for device
implementation code. Use

	make clean

and rebuild when device code changes.

	export AOCL_BOARD_PACKAGE_ROOT=<board_pkg_dir>
	
	source <PATH_TO_INTEL_FPGA_SDK>/<VERSION>/hld/init_opencl.sh
	
	EMULATION=0 make all




Assembler
---------
Example: [examples/fibonacci.asm](examples/fibonacci.asm)	

### Running Programs
`run` Tool Examples:

	# run test.asm program with default scratchpad memory
	scad run test.asm on basic

