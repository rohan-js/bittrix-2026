# Questa Sim - Comprehensive Test Script for Bit-Trix CPU
# Run with: vsim -c -do run_comprehensive.do

# Create work library
vlib work

# Compile all Verilog source files
vlog -work work ../src/alu.v
vlog -work work ../src/instr_decoder.v
vlog -work work ../src/ram.v
vlog -work work ../src/top.v
vlog -work work tb_top_comprehensive.v

# Load the testbench
vsim -c -voptargs="+acc" work.tb_top_comprehensive

# Run simulation
run -all

# Exit
quit -f
