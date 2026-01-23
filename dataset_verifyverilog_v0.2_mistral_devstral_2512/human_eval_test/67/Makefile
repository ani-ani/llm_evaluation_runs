# Cocotb Makefile - Auto-generated
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

PWD := $(shell pwd)
# Source files
VERILOG_SOURCES = $(PWD)/67_gen_0.sv

# Top level module
TOPLEVEL = fruit_distribution

# Python test module
MODULE = 67_testbench

SIM_ARGS += +max_runtime=1000ms

# SystemVerilog support
COMPILE_ARGS += -g2012

# Include cocotb's make rules
include $(shell cocotb-config --makefiles)/Makefile.sim
