# Bit-Trix 2026 - 8-bit CPU Design

**Competition**: Bit-Trix 2026 @ IIITDM Kancheepuram  
**Status**: COMPLETE - ALL TESTS PASSED  
**Test Results**: 16/16 (100% Success Rate)

---

## Overview

An 8-bit Harvard architecture CPU designed for computing impulse response h[n] of discrete-time LTI systems using deconvolution. The design features a custom instruction set with 16 instructions optimized for digital signal processing operations.

### Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Test Cases | 16/16 | PASS |
| Program Size | 227 bytes | PASS (11% under budget) |
| Execution Cycles | 228 | PASS (deterministic) |
| Instructions | 16/16 | PASS (fully utilized) |
| Registers | 4 (R0-R3) | PASS |
| RAM | 64 bytes | PASS |

---

## Features

### Custom ISA v6 (16 Instructions)
- **MSUB**: Single-cycle multiply-subtract (R1 = R1 - rs1 * rs2)
- **SETLO**: Efficient immediate loading for small values (0-3)
- **DIV**: Signed 8-bit division
- **LOADHI/STOREHI**: Direct h[n] array access with auto-increment
- **LOADYI**: Auto-increment y[n] array access

### Design Innovations
1. **Dual Write Port** - Resolves pipeline hazards during LOAD operations
2. **Saturation Arithmetic** - Hardware-based overflow prevention [-128, +127]
3. **Template Compliance** - External PC management via testbench
4. **Optimized Deconvolution** - Single-pass algorithm for h[n] computation

---

## Project Structure

```
bittrix_work/
├── DOCUMENTATION.md          # Complete documentation (all 8 deliverables)
├── TEST_RESULTS.md           # Comprehensive test report
├── SUMMARY.md                # Quick reference guide
├── src/
│   ├── top.v                 # CPU top module
│   ├── alu.v                 # ALU with MSUB + saturation
│   ├── instr_decoder.v       # ISA v6 decoder
│   ├── ram.v                 # 64x8 RAM
│   └── register.v            # 4x8 register file
├── opcode_gen/
│   ├── opcode_gen.py         # Assembler
│   └── program.mem           # Binary program (227 bytes)
├── sim_questa/
│   ├── tb_top_comprehensive.v  # 16-test suite
│   └── run_comprehensive.do    # Simulation script
└── sim_cocotb/
    ├── test_impulse.py       # Cocotb testbench
    ├── Makefile              # Verilator build script
    └── program.mem           # Program binary
```

---

## Quick Start

### Generate Program Binary
```bash
cd opcode_gen
python opcode_gen.py
```

### Run Comprehensive Tests (Questa Sim)
```bash
cd sim_questa
vsim -c -do "do run_comprehensive.do"
```

### Run Cocotb Tests (Verilator + GTKWave)
```bash
cd sim_cocotb
make setup    # Copy program.mem
make          # Run tests
make waves    # Run with waveform viewer
```

---

## Algorithm: Deconvolution

### Mathematical Formula
```
h[n] = (y[n] - SUM(h[k] * x[n-k], k=0 to n-1)) / x[0]
```

### Implementation
- **Input**: x[0-7] at RAM addresses 0-7, y[0-7] at addresses 8-15
- **Output**: h[0-7] at RAM addresses 16-23
- **Method**: Iterative deconvolution with multiply-subtract accumulation

### Register Allocation
- **R0**: x[0] (constant divisor)
- **R1**: Accumulator (sum, result)
- **R2**: Loaded h[k] values
- **R3**: Address pointer (auto-increment)

---

## Test Results

### Test Suite (16 Tests)
All 16 comprehensive tests passed covering:

1. Basic impulse response
2. Delta function (x[n]=δ[n])
3. Scaled impulse
4. Two-tap and three-tap filters
5. Negative values (x, y, h)
6. Maximum positive (+127) and negative (-128)
7. Large sign changes
8. Near-overflow scenarios
9. Negative x[0] (negative division)
10. Large divisors

**Execution**: 228 cycles (consistent across all tests)

See [TEST_RESULTS.md](TEST_RESULTS.md) for detailed results.

---

## ISA v6 Instruction Set

| Opcode | Mnemonic | Function | Cycles |
|--------|----------|----------|--------|
| 0000 | NOP | No operation | 1 |
| 0001 | ADD | rd = rs1 + rs2 | 1 |
| 0010 | SETLO | rd = imm (0-3) | 1 |
| 0011 | MSUB | R1 = R1 - rs1 * rs2 | 1 |
| 0100 | DIV | rd = rs1 / rs2 | 1 |
| 0101 | LOAD | rd = RAM[rs2] | 2 |
| 0110 | STORE | RAM[rs2] = rs1 | 1 |
| 0111 | MOV | rd = rs1 | 1 |
| 1000 | LDI | rd = imm8 | 2 |
| 1001 | LOADHI | rd = RAM[16+rs2] | 2 |
| 1010 | LOADYI | rd = RAM[8+rs2++] | 2 |
| 1011 | STOREHI | RAM[16+rs2++] = rs1 | 1 |
| 1100 | INC | rd = rd + 1 | 1 |
| 1101 | CLR | rd = 0 | 1 |
| 1110 | DEC | rd = rd - 1 | 1 |
| 1111 | HLT | Halt execution | 1 |

---

## Deliverables

All 8 competition requirements completed:

1. [PASS] ALU and Functional Block Diagrams
2. [PASS] Instruction Set Table (16 instructions)
3. [PASS] Datapath Explanation and Register Usage Strategy
4. [PASS] Memory Access Strategy
5. [PASS] Overflow/Saturation Documentation
6. [PASS] Verilog RTL Implementation
7. [PASS] Assembly Code to Compute h[n]
8. [PASS] Execution Trace

See [DOCUMENTATION.md](DOCUMENTATION.md) for complete details.

---

## Hardware Specifications

### Architecture
- **Type**: Harvard (separate instruction/data memory)
- **Data Width**: 8 bits (signed)
- **Registers**: 4 general-purpose (R0-R3)
- **RAM**: 64 bytes (addresses 0-63)
- **Instructions**: 16 (4-bit opcode)

### ALU Operations
- ADD (with saturation)
- DIV (signed division)
- MSUB (multiply-subtract with accumulation)
- MOV, INC, DEC, CLR

### Memory Map
- Addresses 0-7: x[n] input samples
- Addresses 8-15: y[n] output samples
- Addresses 16-23: h[n] computed impulse response
- Addresses 24-63: Available for intermediate values

---

## Performance

- **Execution Time**: 228 cycles (deterministic)
- **Clock Period**: 10 ns (100 MHz target)
- **Total Time**: 2.28 μs per computation
- **Program Size**: 227 bytes (29 bytes under limit)
- **Resource Utilization**: 100% (all 16 instructions used)

---

## Competition Readiness

- [PASS] All 8 deliverables documented
- [PASS] 16/16 tests passing (100%)
- [PASS] Program under 256-byte limit
- [PASS] Template interface compliance
- [PASS] Cocotb testbench ready
- [PASS] Questa Sim verification complete
- [PASS] Edge cases handled
- [PASS] Saturation logic verified
- [PASS] Execution trace documented

---

## Tools & Environment

### Development
- **Simulator**: Questa Sim 2024.1 (Windows 64-bit)
- **Language**: Verilog-2001
- **Python**: 3.13 (for assembler)

### Competition Environment
- **Simulator**: Verilator
- **Testing**: Cocotb
- **Waveforms**: GTKWave
- **Platform**: Linux/Unix

---

## Documentation

- **[DOCUMENTATION.md](DOCUMENTATION.md)** - Complete technical documentation with all 8 deliverables
- **[TEST_RESULTS.md](TEST_RESULTS.md)** - Detailed test results and verification
- **[SUMMARY.md](SUMMARY.md)** - Quick reference and competition summary

---

## License

This project was developed for the Bit-Trix 2026 hardware-software co-design competition at IIITDM Kancheepuram.

---

**Last Updated**: March 30, 2026  
**Version**: ISA v6 (Final)  
**Status**: Ready for Submission
