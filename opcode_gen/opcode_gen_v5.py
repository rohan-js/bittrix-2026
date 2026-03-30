#!/usr/bin/env python3
"""
Bit-Trix Assembler - ISA v5 with MSUB (Multiply-Subtract)
MSUB: R1 = R1 - Rd * Rs2 (saves one instruction per multiply-accumulate)
"""

OPCODES = {
    "NOP": 0, "ADD": 1, "SUB": 2, "MSUB": 3, "DIV": 4, "LOAD": 5,
    "STORE": 6, "MOV": 7, "LDI": 8, "LOADHI": 9, "LOADYI": 10, "STOREHI": 11,
    "INC": 12, "CLR": 13, "DEC": 14, "HLT": 15
}
R = {"R0": 0, "R1": 1, "R2": 2, "R3": 3}
P = []

def E(op, rd, rs2=0):
    rd_v = R[rd] if rd in R else rd
    rs2_v = R[rs2] if rs2 in R else (rs2 & 3)
    P.append((OPCODES[op] << 4) | (rd_v << 2) | rs2_v)

def LDI(rd, imm):
    E("LDI", rd, 0)
    P.append(imm & 0xFF)

# Memory: x[0-7]@0-7, y[0-7]@8-15, h[0-7]@16-23
# R0 = x[0] (const), R1 = accumulator, R2 = h[k] or temp, R3 = index
# MSUB: R1 = R1 - R2 * R3 (always uses R1 as accumulator, R2 and R3 as operands)

# ===== INIT: R0 = x[0] =====
E("CLR", "R3")           # R3 = 0
E("LOAD", "R0", "R3")    # R0 = x[0]
E("NOP", "R0")           # wait for RAM

# ===== h[0] = y[0] / x[0] =====
E("CLR", "R3")
E("LOADYI", "R1", "R3")  # R1 = y[0]
E("NOP", "R0")           # wait
E("DIV", "R1", "R0")     # R1 = h[0]
E("CLR", "R3")
E("STOREHI", "R1", "R3") # h[0] stored, R3=1

# ===== h[1] = (y[1] - h[0]*x[1]) / x[0] =====
# Need: R1 = y[1], then R1 = R1 - h[0]*x[1]
# Load y[1] first
E("LOADYI", "R1", "R3")  # R1 = y[1] (R3=1)
E("CLR", "R3")           # R3 = 0 (also wait cycle)
# Load h[0]
E("LOADHI", "R2", "R3")  # R2 = h[0], R3=1 after
E("LOAD", "R3", "R3")    # R3 = x[1] (addr=1) - overlaps wait
E("NOP", "R0")           # wait for x[1]
E("MSUB", "R2", "R3")    # R1 = R1 - R2*R3
E("DIV", "R1", "R0")
E("CLR", "R3"); E("INC", "R3")  # R3 = 1
E("STOREHI", "R1", "R3") # h[1], R3=2

# ===== h[2] = (y[2] - h[0]*x[2] - h[1]*x[1]) / x[0] =====
E("LOADYI", "R1", "R3")  # R1 = y[2] (R3=2)
E("CLR", "R3")           # R3 = 0
# h[0]*x[2]
E("LOADHI", "R2", "R3")  # R2 = h[0], R3=1
LDI("R3", 2)             # R3 = 2 (also wait)
E("LOAD", "R3", "R3")    # R3 = x[2]
E("NOP", "R0")
E("MSUB", "R2", "R3")    # R1 = R1 - h[0]*x[2]
# h[1]*x[1]
E("CLR", "R3"); E("INC", "R3")  # R3 = 1
E("LOADHI", "R2", "R3")  # R2 = h[1], R3=2
E("CLR", "R3"); E("INC", "R3")  # R3 = 1
E("LOAD", "R3", "R3")    # R3 = x[1]
E("NOP", "R0")
E("MSUB", "R2", "R3")    # R1 = R1 - h[1]*x[1]
E("DIV", "R1", "R0")
LDI("R3", 2)
E("STOREHI", "R1", "R3") # h[2], R3=3

# ===== h[3] =====
E("LOADYI", "R1", "R3")  # y[3]
E("CLR", "R3")
# h[0]*x[3]
E("LOADHI", "R2", "R3")  # h[0], R3=1
LDI("R3", 3)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[1]*x[2]
E("CLR", "R3"); E("INC", "R3")
E("LOADHI", "R2", "R3")  # h[1], R3=2
E("LOAD", "R3", "R3")    # x[2]
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[2]*x[1]
E("CLR", "R3"); E("INC", "R3"); E("INC", "R3")  # R3=2
E("LOADHI", "R2", "R3")  # h[2], R3=3
E("CLR", "R3"); E("INC", "R3")  # R3=1
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
E("DIV", "R1", "R0")
LDI("R3", 3)
E("STOREHI", "R1", "R3") # h[3], R3=4

# ===== h[4] =====
E("LOADYI", "R1", "R3")  # y[4]
E("CLR", "R3")
# h[0]*x[4]
E("LOADHI", "R2", "R3")
LDI("R3", 4)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[1]*x[3]
E("CLR", "R3"); E("INC", "R3")
E("LOADHI", "R2", "R3")
LDI("R3", 3)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[2]*x[2]
E("CLR", "R3"); E("INC", "R3"); E("INC", "R3")
E("LOADHI", "R2", "R3")  # R3=3 after
E("DEC", "R3")           # R3=2
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[3]*x[1]
LDI("R3", 3)
E("LOADHI", "R2", "R3")  # R3=4 after
E("CLR", "R3"); E("INC", "R3")
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
E("DIV", "R1", "R0")
LDI("R3", 4)
E("STOREHI", "R1", "R3") # h[4], R3=5

# ===== h[5] =====
E("LOADYI", "R1", "R3")  # y[5]
E("CLR", "R3")
# h[0]*x[5]
E("LOADHI", "R2", "R3")
LDI("R3", 5)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[1]*x[4]
E("CLR", "R3"); E("INC", "R3")
E("LOADHI", "R2", "R3")
LDI("R3", 4)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[2]*x[3]
E("CLR", "R3"); E("INC", "R3"); E("INC", "R3")
E("LOADHI", "R2", "R3")
E("LOAD", "R3", "R3")    # x[3], R3=3
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[3]*x[2]
LDI("R3", 3)
E("LOADHI", "R2", "R3")  # R3=4 after
E("DEC", "R3"); E("DEC", "R3")  # R3=2
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[4]*x[1]
LDI("R3", 4)
E("LOADHI", "R2", "R3")  # R3=5
E("CLR", "R3"); E("INC", "R3")
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
E("DIV", "R1", "R0")
LDI("R3", 5)
E("STOREHI", "R1", "R3") # h[5], R3=6

# ===== h[6] =====
E("LOADYI", "R1", "R3")  # y[6]
E("CLR", "R3")
# h[0]*x[6]
E("LOADHI", "R2", "R3")
LDI("R3", 6)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[1]*x[5]
E("CLR", "R3"); E("INC", "R3")
E("LOADHI", "R2", "R3")
LDI("R3", 5)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[2]*x[4]
E("CLR", "R3"); E("INC", "R3"); E("INC", "R3")
E("LOADHI", "R2", "R3")
LDI("R3", 4)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[3]*x[3]
LDI("R3", 3)
E("LOADHI", "R2", "R3")  # R3=4 after
E("DEC", "R3")           # R3=3
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[4]*x[2]
LDI("R3", 4)
E("LOADHI", "R2", "R3")  # R3=5
E("CLR", "R3"); E("INC", "R3"); E("INC", "R3")
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[5]*x[1]
LDI("R3", 5)
E("LOADHI", "R2", "R3")
E("CLR", "R3"); E("INC", "R3")
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
E("DIV", "R1", "R0")
LDI("R3", 6)
E("STOREHI", "R1", "R3") # h[6], R3=7

# ===== h[7] =====
E("LOADYI", "R1", "R3")  # y[7]
E("CLR", "R3")
# h[0]*x[7]
E("LOADHI", "R2", "R3")
LDI("R3", 7)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[1]*x[6]
E("CLR", "R3"); E("INC", "R3")
E("LOADHI", "R2", "R3")
LDI("R3", 6)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[2]*x[5]
E("CLR", "R3"); E("INC", "R3"); E("INC", "R3")
E("LOADHI", "R2", "R3")
LDI("R3", 5)
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[3]*x[4]
LDI("R3", 3)
E("LOADHI", "R2", "R3")
E("LOAD", "R3", "R3")    # x[4], R3=4 after LOADHI
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[4]*x[3]
LDI("R3", 4)
E("LOADHI", "R2", "R3")  # R3=5
E("DEC", "R3"); E("DEC", "R3")  # R3=3
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[5]*x[2]
LDI("R3", 5)
E("LOADHI", "R2", "R3")  # R3=6
E("CLR", "R3"); E("INC", "R3"); E("INC", "R3")
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
# h[6]*x[1]
LDI("R3", 6)
E("LOADHI", "R2", "R3")
E("CLR", "R3"); E("INC", "R3")
E("LOAD", "R3", "R3")
E("NOP", "R0")
E("MSUB", "R2", "R3")
E("DIV", "R1", "R0")
LDI("R3", 7)
E("STOREHI", "R1", "R3") # h[7]

E("HLT", "R0")

print(f"Total: {len(P)} bytes")
if len(P) <= 256:
    print(f"OK! {256-len(P)} bytes free")
else:
    print(f"OVER by {len(P)-256}")

with open("program.mem", "w") as f:
    for c in P: f.write(format(c, '08b') + "\n")
with open("program.hex", "w") as f:
    for c in P: f.write(format(c, '02x') + "\n")
