# ============================================================================
# Bit-Trix Testbench Makefile
# Cocotb + Verilator + GTKWave Simulation
# For organizer testing environment
# ============================================================================

TOPLEVEL_LANG = verilog
SIM = verilator

# Top module name
TOPLEVEL = top

# Cocotb test module (without .py extension)
MODULE = test_impulse

# Verilog source files (template-compliant - no PC or instruction RAM)
VERILOG_SOURCES = \
    $(PWD)/../src/alu.v \
    $(PWD)/../src/instr_decoder.v \
    $(PWD)/../src/register.v \
    $(PWD)/../src/ram.v \
    $(PWD)/../src/top.v

# Enable waveform tracing for GTKWave
EXTRA_ARGS += --trace --trace-structs

# Verilator flags
VERILATOR_FLAGS += -Wall
VERILATOR_FLAGS += -Wno-fatal
VERILATOR_FLAGS += -Wno-WIDTHTRUNC
VERILATOR_FLAGS += -Wno-WIDTHEXPAND

# Include cocotb makefile
include $(shell cocotb-config --makefiles)/Makefile.sim

# Setup: Copy memory files
.PHONY: setup
setup:
	cp ../opcode_gen/program.mem .
	@echo "Memory files copied. Ready for simulation."

# Run simulation with waveform
.PHONY: waves
waves: setup
	$(MAKE) && gtkwave dump.vcd &

# Clean simulation artifacts
.PHONY: clean_all
clean_all: clean
	rm -rf sim_build __pycache__ results.xml dump.vcd *.vcd program.mem
