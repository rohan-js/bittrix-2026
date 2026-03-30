# Questa Sim - TCL Script for Bit-Trix CPU Simulation - ISA v6
# Run with: vsim -do run_sim.do

# Create work library
vlib work

# Compile all Verilog source files
vlog -work work ../src/alu.v
vlog -work work ../src/instr_decoder.v
vlog -work work ../src/ram.v
vlog -work work ../src/top.v
vlog -work work tb_top.v

# Load the testbench
vsim -voptargs="+acc" work.tb_top

# Add waves
add wave -divider "Clock & Reset"
add wave /tb_top/clk
add wave /tb_top/rst

add wave -divider "CPU Control"
add wave -radix unsigned /tb_top/pc
add wave -radix binary /tb_top/instr
add wave /tb_top/halted
add wave -radix unsigned /tb_top/cycle_count

add wave -divider "Registers"
add wave -radix decimal /tb_top/dut/regs[0]
add wave -radix decimal /tb_top/dut/regs[1]
add wave -radix decimal /tb_top/dut/regs[2]
add wave -radix decimal /tb_top/dut/regs[3]

add wave -divider "Decoder Signals"
add wave -radix binary /tb_top/dut/opcode
add wave -radix unsigned /tb_top/dut/rd
add wave -radix unsigned /tb_top/dut/rs2
add wave /tb_top/dut/reg_wr_en
add wave /tb_top/dut/ram_wr_en
add wave /tb_top/dut/alu_en
add wave /tb_top/dut/msub_en
add wave /tb_top/dut/setlo_en

add wave -divider "ALU"
add wave -radix decimal /tb_top/dut/rs1_data
add wave -radix decimal /tb_top/dut/rs2_data
add wave -radix decimal /tb_top/dut/r1_data
add wave -radix decimal /tb_top/dut/alu_result
add wave -radix decimal /tb_top/dut/msub_result

add wave -divider "Memory Access"
add wave -radix unsigned /tb_top/dut/ram_addr
add wave -radix decimal /tb_top/dut/ram_rd_data
add wave /tb_top/dut/load_pending

add wave -divider "Pipeline"
add wave /tb_top/dut/ldi_pending
add wave /tb_top/dut/load_pending
add wave /tb_top/dut/autoinc_pending

# Run simulation
run -all

# Zoom to fit all
wave zoom full
