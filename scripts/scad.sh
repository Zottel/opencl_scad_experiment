#!/bin/bash -e

# Expects ALTERAOCLSDKROOT to be set by system
# (It is on es86)
source "$ALTERAOCLSDKROOT/init_opencl.sh"

# Base dir for SCAD machine parts.
SCADMACHINEROOT=/opt/scad

# Default values
MACHINE=basic
PROGRAM=

function usage {
echo "Usage: $0 run <program> on <device name>"
echo
echo "Example: $0 run fibonacci.asm on basic"
echo
}

while [[ $# -gt 1 ]]
do
	case "$1" in
		on)
			MACHINE="$2"
			shift # past argument
			;;
		run)
			PROGRAM="$2"
			shift # past argument
			;;
		*)
			usage
			exit
			;;
	esac
	shift # past argument or value
done

if [ -z "$PROGRAM" ]
then
	echo "no program given"
	echo
	usage
	exit
fi

# Only check .xml for now - run will give its own error.
if [ ! -f "$SCADMACHINEROOT/processors/$MACHINE.xml" ]
then
	echo "Machine description file not found: $SCADMACHINEROOT/processors/$MACHINE.xml"
	echo
	usage
	exit
fi

CL_CONTEXT_EMULATOR_DEVICE_ALTERA=1 $SCADMACHINEROOT/bin/run "$SCADMACHINEROOT/processors/$MACHINE.xml" "$SCADMACHINEROOT/processors/$MACHINE.aocx" "$PROGRAM"

