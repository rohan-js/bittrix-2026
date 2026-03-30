# Debug simulation script for Questa Sim
# Traces Test 14 execution step-by-step

# Quit any existing simulation
quit -sim

# Create work library if it doesn't exist
if {![file exists work]} {
    vlib work
}

# Compile source files
vlog -work work ../src/ram.v
vlog -work work ../src/alu.v
vlog -work work ../src/instr_decoder.v
vlog -work work ../src/top.v
vlog -work work tb_debug.v

# Run simulation
vsim -c -t 1ns work.tb_debug -do "run -all; quit"
