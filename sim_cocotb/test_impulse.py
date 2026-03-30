"""
Bit-Trix Cocotb Testbench - test_impulse.py
Tests the deconvolution algorithm for computing impulse response h[n]
For Cocotb + Verilator + GTKWave testing environment

NOTE: The template interface has instructions fed EXTERNALLY via `instr` input.
The testbench manages the PC and feeds instructions to the CPU.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Clock period in nanoseconds
CLK_PERIOD_NS = 10

# Memory map constants
X_BASE = 0   # x[0] to x[7]: addresses 0-7
Y_BASE = 8   # y[0] to y[7]: addresses 8-15
H_BASE = 16  # h[0] to h[7]: addresses 16-23

# Opcode definitions (ISA v6)
OP_NOP    = 0b0000
OP_ADD    = 0b0001
OP_SETLO  = 0b0010
OP_MSUB   = 0b0011
OP_DIV    = 0b0100
OP_LOAD   = 0b0101
OP_STORE  = 0b0110
OP_MOV    = 0b0111
OP_LDI    = 0b1000
OP_LOADHI = 0b1001
OP_LOADYI = 0b1010
OP_STOREHI= 0b1011
OP_INC    = 0b1100
OP_CLR    = 0b1101
OP_DEC    = 0b1110
OP_HLT    = 0b1111


def to_signed(val):
    """Convert unsigned 8-bit to signed"""
    if val > 127:
        return val - 256
    return val


class BitTrixTestbench:
    """Testbench for Bit-Trix CPU"""
    
    def __init__(self, dut, program):
        self.dut = dut
        self.program = program  # List of 8-bit instruction bytes
        self.pc = 0
        self.halted = False
        self.ldi_pending = False
        
    async def reset(self):
        """Apply reset to DUT"""
        self.dut.rst.value = 1
        self.pc = 0
        self.halted = False
        self.ldi_pending = False
        for _ in range(5):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        self.dut.instr.value = self.program[0] if self.program else 0
        await RisingEdge(self.dut.clk)
        
    async def init_ram(self, x_data, y_data):
        """Initialize RAM with test data"""
        ram = self.dut.u_ram.mem
        
        # Initialize x[n] at addresses 0-7
        for i, val in enumerate(x_data):
            ram[i].value = val & 0xFF
        
        # Initialize y[n] at addresses 8-15
        for i, val in enumerate(y_data):
            ram[Y_BASE + i].value = val & 0xFF
        
        # Clear h[n] area at addresses 16-23
        for i in range(8):
            ram[H_BASE + i].value = 0
        
        await RisingEdge(self.dut.clk)
    
    def update_pc(self, instr):
        """Update PC based on current instruction (mirrors testbench logic)"""
        if self.halted:
            return
            
        opcode = (instr >> 4) & 0xF
        
        if opcode == OP_LDI and not self.ldi_pending:
            self.ldi_pending = True
            self.pc += 1
        elif self.ldi_pending:
            self.ldi_pending = False
            self.pc += 1
        elif opcode == OP_HLT:
            self.halted = True
        else:
            self.pc += 1
            
    async def run_until_halt(self, max_cycles=500):
        """Run program until HLT instruction or max cycles"""
        for cycle in range(max_cycles):
            # Feed current instruction
            if self.pc < len(self.program):
                instr = self.program[self.pc]
                self.dut.instr.value = instr
            else:
                self.dut.instr.value = (OP_HLT << 4)  # Default to HLT
                
            await RisingEdge(self.dut.clk)
            
            # Update PC after clock edge
            if self.pc < len(self.program):
                self.update_pc(self.program[self.pc])
            
            if self.halted:
                self.dut._log.info(f"CPU halted at cycle {cycle}")
                return cycle
                
            if cycle % 50 == 0 and cycle > 0:
                self.dut._log.info(f"Cycle {cycle}: running... PC={self.pc}")
        
        self.dut._log.warning(f"CPU did not halt within {max_cycles} cycles")
        return max_cycles
    
    async def read_h_results(self):
        """Read computed h[n] from RAM"""
        ram = self.dut.u_ram.mem
        h_results = []
        for i in range(8):
            val = int(ram[H_BASE + i].value)
            h_results.append(to_signed(val))
        return h_results


def load_program(filename="program.mem"):
    """Load program from binary memory file"""
    program = []
    try:
        with open(filename, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('//'):
                    program.append(int(line, 2))
    except FileNotFoundError:
        # Return empty program if file not found
        pass
    return program


# Test data sets
TEST_CASES = [
    # Test 1: Simple impulse
    {
        'name': 'Simple impulse',
        'x': [2, 0, 0, 0, 0, 0, 0, 0],
        'y': [2, 0, 0, 0, 0, 0, 0, 0],
        'expected_h': [1, 0, 0, 0, 0, 0, 0, 0]
    },
    # Test 2: h[n] = [1, 1]
    {
        'name': 'Two-tap response',
        'x': [2, 1, 0, 0, 0, 0, 0, 0],
        'y': [2, 3, 1, 0, 0, 0, 0, 0],
        'expected_h': [1, 1, 0, 0, 0, 0, 0, 0]
    },
    # Test 3: All ones
    {
        'name': 'All ones input',
        'x': [1, 1, 1, 1, 1, 1, 1, 1],
        'y': [1, 1, 1, 1, 1, 1, 1, 1],
        'expected_h': [1, 0, 0, 0, 0, 0, 0, 0]
    },
]


@cocotb.test()
async def test_deconvolution_basic(dut):
    """Test 1: Basic deconvolution with simple impulse"""
    
    # Load program
    program = load_program("program.mem")
    if not program:
        dut._log.error("Failed to load program.mem")
        assert False, "Program file not found"
    
    dut._log.info(f"Loaded program with {len(program)} instructions")
    
    # Create testbench
    tb = BitTrixTestbench(dut, program)
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    
    # Test case
    test = TEST_CASES[0]
    
    dut._log.info("=" * 60)
    dut._log.info(f"  TEST: {test['name']}")
    dut._log.info("=" * 60)
    dut._log.info(f"Input x[n]:    {test['x']}")
    dut._log.info(f"Output y[n]:   {test['y']}")
    dut._log.info(f"Expected h[n]: {test['expected_h']}")
    dut._log.info("=" * 60)
    
    # Reset and initialize
    await tb.reset()
    await tb.init_ram(test['x'], test['y'])
    
    # Run program
    cycles = await tb.run_until_halt()
    
    # Wait for final writes
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    # Read results
    h_results = await tb.read_h_results()
    
    # Get cycle count
    total_cycles = int(dut.cycle_count.value)
    
    # Print results
    dut._log.info("=" * 60)
    dut._log.info("  RESULTS")
    dut._log.info("=" * 60)
    dut._log.info(f"Computed h[n]: {h_results}")
    dut._log.info(f"Expected h[n]: {test['expected_h']}")
    dut._log.info(f"Total cycles:  {total_cycles}")
    dut._log.info("=" * 60)
    
    # Verify results (h[0] through h[7])
    passed = True
    for i in range(8):
        if h_results[i] != test['expected_h'][i]:
            dut._log.error(f"Mismatch at h[{i}]: got {h_results[i]}, expected {test['expected_h'][i]}")
            passed = False
    
    if passed:
        dut._log.info("TEST PASSED!")
    else:
        dut._log.error("TEST FAILED!")
    
    assert passed, "Deconvolution result mismatch"


@cocotb.test()
async def test_deconvolution_two_tap(dut):
    """Test 2: Two-tap impulse response"""
    
    program = load_program("program.mem")
    if not program:
        assert False, "Program file not found"
    
    tb = BitTrixTestbench(dut, program)
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    
    test = TEST_CASES[1]
    
    dut._log.info("=" * 60)
    dut._log.info(f"  TEST: {test['name']}")
    dut._log.info("=" * 60)
    
    await tb.reset()
    await tb.init_ram(test['x'], test['y'])
    
    cycles = await tb.run_until_halt()
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    h_results = await tb.read_h_results()
    
    dut._log.info(f"Computed h[n]: {h_results}")
    dut._log.info(f"Expected h[n]: {test['expected_h']}")
    
    passed = all(h_results[i] == test['expected_h'][i] for i in range(8))
    
    if passed:
        dut._log.info("TEST PASSED!")
    else:
        dut._log.error("TEST FAILED!")
    
    assert passed, "Deconvolution result mismatch"


@cocotb.test()
async def test_cycle_count(dut):
    """Test: Measure cycle count for performance evaluation"""
    
    program = load_program("program.mem")
    if not program:
        assert False, "Program file not found"
    
    tb = BitTrixTestbench(dut, program)
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    
    # Use delta function: x=[1,0,...], y=[1,0,...]
    await tb.reset()
    await tb.init_ram([1, 0, 0, 0, 0, 0, 0, 0], [1, 0, 0, 0, 0, 0, 0, 0])
    
    cycles = await tb.run_until_halt()
    
    total_cycles = int(dut.cycle_count.value)
    total_time_ns = total_cycles * CLK_PERIOD_NS
    
    dut._log.info("=" * 50)
    dut._log.info("  PERFORMANCE SUMMARY")
    dut._log.info("=" * 50)
    dut._log.info(f"Program size   : {len(program)} bytes")
    dut._log.info(f"Total Cycles   : {total_cycles}")
    dut._log.info(f"Clock Period   : {CLK_PERIOD_NS} ns")
    dut._log.info(f"Total Time     : {total_time_ns} ns")
    dut._log.info("=" * 50)
    
    # Competition metric: lower cycles = better
    assert total_cycles < 500, f"Too many cycles: {total_cycles}"
    dut._log.info(f"PASSED: Execution completed in {total_cycles} cycles")
