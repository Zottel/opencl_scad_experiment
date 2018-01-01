################################################################################
# Settings

QUIET := 0
EMULATION ?= 0

# Installation prefix:
PREFIX := /opt/scad

ifeq ($(strip $(EMULATION)),1)
EMULATION_ENV := CL_CONTEXT_EMULATOR_DEVICE_ALTERA=1
else
EMULATION_ENV := 
endif

ifneq ($(strip $(QUIET)),1)
ECHO :=
else
ECHO := @
endif

################################################################################
# General Rules

CPP_DIRS := common host host_lib
CPP_DIRS_INCLUDES := $(foreach dir, $(CPP_DIRS), -I $(dir))

HOST_EXECUTABLE_SOURCES := $(wildcard host/*.cpp)
HOST_EXECUTABLES := $(HOST_EXECUTABLE_SOURCES:.cpp=)
CPP_LIB_SOURCES := $(wildcard host_lib/*.cpp)
$(info CPP_LIB_SOURCE: $(CPP_LIB_SOURCES))

# Each configured processor consists of one file that includes everything
# in the corresponding folder.
# Example: device/basic.cl includes device/basic_components/buffer.cl
#                                   device/basic_components/channels.cl
#                                   ...
EXAMPLE_PROGRAMS := $(wildcard examples/*)
SCAD_CONFIG_DIR := device
SCAD_CONFIGURATIONS := $(filter %.xml, $(foreach dir, $(SCAD_CONFIG_DIR), $(wildcard $(dir)/*)))
SCAD_CONFIGURED_SOURCES := $(SCAD_CONFIGURATIONS:.xml=.cl)
SCAD_CONFIGURED_EXECUTABLES := $(SCAD_CONFIGURATIONS:.xml=.aocx)
SCAD_CONFIGURED_DIRS := $(SCAD_CONFIGURATIONS:.xml=_components)
SCAD_SYNTHESIS_DIRS := $(SCAD_CONFIGURATIONS:.xml=)
CL_LIBRARY_DIR := device_lib
CL_LIBRARIES := $(filter %.cl, $(foreach dir, $(CL_LIBRARY_DIR), $(wildcard $(dir)/*)))

all: $(HOST_EXECUTABLES) $(SCAD_CONFIGURED_EXECUTABLES)

.PHONY: test

test: all
	@echo
	@echo '##################################################################################################'
	@echo '# fibonacci.asm:'
	@#$(ECHO)$(EMULATION_ENV) host/run device/basic.xml device/basic.aocx examples/fibonacci.asm
	$(ECHO)$(EMULATION_ENV) host/run device/basic.xml device/basic.aocx examples/fibonacci.asm

install: all
	mkdir -p -m 755 $(PREFIX)/bin
	install -b -S -m 755 HOST_EXECUTABLES $(PREFIX)/bin/
	install -b -S -m 755 scripts/scad.sh $(PREFIX)/bin/scad
	mkdir -p -m 755 $(PREFIX)/processors
	install -b -S -m 644 $(SCAD_CONFIGURATIONS) $(SCAD_CONFIGURED_EXECUTABLES) $(PREFIX)/processors/
	mkdir -p -m 755 $(PREFIX)/examples
	install -b -S -m 644 $(wildcard examples/*) $(PREFIX)/examples/

clean:
	$(ECHO)rm -f host/*.o host/*.d host_lib/*.o host_lib/*.d $(HOST_EXECUTABLES)
	$(ECHO)rm -f $(SCAD_CONFIGURED_SOURCES)
	$(ECHO)rm -Rf $(SCAD_CONFIGURED_DIRS) $(SCAD_SYNTHESIS_DIRS)


################################################################################
# Compiler Flags

TOPDIR := $(dir $(lastword $(MAKEFILE_LIST)))

# Altera OpenCL compiler
AOC := aoc
AOCL := aocl

AOC_VERSION := $(shell aoc --version | grep -o 'Version [0-9]*' | grep -o '[0-9]*')
ifndef AOC_VERSION
$(error 'aoc version not found, are you sure you have a working environment?')
endif


AOCFLAGS := --high-effort -g --report --profile -I $(TOPDIR) \
            -DAOC_VERSION=$(AOC_VERSION) \
            -O3 \
            --dot \
            --time --time-passes

ifneq ($(strip $(QUIET)),1)
AOCFLAGS += -v
endif

ifeq ($(strip $(EMULATION)),1)
AOC_EMULATION := -march=emulator -DEMULATOR=1
ifeq ($(strip $(AOC_VERSION)),17)
AOC_EMULATION += --emulator-channel-depth-model strict
endif
endif


# C/C++ flags required for OpenCL binding
AOCL_COMPILE_CONFIG := $(shell $(AOCL) compile-config )
AOCL_LINK_CONFIG := $(shell $(AOCL) link-config )
AOCL_LDFLAGS := $(shell $(AOCL) ldflags )
AOCL_LDLIBS := $(shell $(AOCL) ldlibs )

# C++ compiler
CXX := $(ECHO)clang++
CXXFLAGS := -Wall -Wextra -Wno-unused-parameter -Wno-unused \
            -DPREFIX=$(PREFIX) -DAOC_VERSION=$(AOC_VERSION)\
            -x c++ -std=c++11 -stdlib=libstdc++ -I$(TOPDIR) \
            $(CPP_DIRS_INCLUDES) \
            $(AOCL_COMPILE_CONFIG) \
            -Wno-unknown-pragmas \
            -Wno-ignored-qualifiers \
            -g

LDFLAGS := -std=c++11 -stdlib=libstdc++
#LDFLAGS += -Wl,-dead_strip

# Emulation
# /etc/OpenCL/vendors/Altera.icd  needs to match the one in $(ALTERAOCLSDKROOT)
ifdef AOC_EMULATION
LDFLAGS += $(AOCL_LDFLAGS) -lOpenCL $(AOCL_LDLIBS)
else
# To FPGA
LDFLAGS += $(AOCL_LINK_CONFIG)
endif #ifdef AOC_EMULATION

ifneq ($(strip $(QUIET)),1)
$(info ---------------------------)
$(info CXX: $(CXX))
$(info CXXFLAGS: $(CXXFLAGS))
$(info LDFLAGS: $(LDFLAGS))
$(info AOC: $(AOC))
$(info AOCFLAGS: $(AOCFLAGS))
$(info AOCL_COMPILE_CONFIG: $(AOCL_COMPILE_CONFIG))
$(info AOCL_LINK_CONFIG: $(AOCL_LINK_CONFIG))
$(info AOCL_LDFLAGS: $(AOCL_LDFLAGS))
$(info AOCL_LDLIBS: $(AOCL_LDLIBS))
$(info ---------------------------)
endif


################################################################################
# External tools support

.PHONY: -print-cxxflags
-print-cxxflags:
	@echo -n $(CXXFLAGS)


################################################################################
# Compiler Rules

host/%: host/%.cpp $(CPP_LIB_SOURCES) Makefile
	$(ECHO)clang++ $(CXXFLAGS) $(filter %.cpp, $^) $(LDFLAGS) -o $@

# Create SCAD machine processor sources from xml description
device/%.cl: device/%.xml host/configure Makefile
	host/configure $< device_implementations

device/%.aocx: device/%.cl $(CL_LIBRARIES) Makefile
	# Synthesis
	$(ECHO)time -v $(AOC) $(AOC_EMULATION) $(AOCFLAGS) $(filter %.cl, $^) -o $@
	# Result statistics
ifneq ($(strip $(EMULATION)),1)
	$(ECHO)$(AOCL) analyze-area $(@:.aocx=.aoco)
	cp $(@:.aocx=/quartus_sh_compile.log) $@_quartus_sh_compile.log
	cp $(@:.aocx=/acl_quartus_report.txt) $@_acl_quartus_report.txt
endif

