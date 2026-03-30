`timescale 1ns/1ps
//============================================================================
// Testbench for Bit-Trix CPU - ISA v6
// External instruction feed (matching template interface)
//============================================================================

module tb_top;

    // Clock and reset
    reg clk;
    reg rst;
    reg [7:0] instr;
    
    // DUT outputs
    wire [255:0] cycle_count;
    
    // Instantiate DUT
    top dut (
        .clk         (clk),
        .rst         (rst),
        .instr       (instr),
        .cycle_count (cycle_count)
    );
    
    // Program memory (external to DUT, per template interface)
    reg [7:0] prog_mem [0:255];
    reg [7:0] pc;
    
    // Clock generation: 10ns period (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test variables
    integer i;
    integer cycle;
    reg done;
    reg halted;
    
    // LDI state tracking (to know when to feed immediate byte)
    reg ldi_pending;
    
    // Load program from file
    initial begin
        $readmemb("program.mem", prog_mem);
    end
    
    // Load test data into RAM
    initial begin
        // Test case: Simple impulse response
        // x[n] = [2, 0, 0, 0, 0, 0, 0, 0]
        // y[n] = [4, 2, 0, 0, 0, 0, 0, 0]
        // Expected h[n] = [2, 1, 0, 0, 0, 0, 0, 0]
        
        // Initialize x[0-7] at addresses 0-7
        dut.u_ram.mem[0] = 8'd2;   // x[0] = 2
        dut.u_ram.mem[1] = 8'd0;   // x[1] = 0
        dut.u_ram.mem[2] = 8'd0;   // x[2] = 0
        dut.u_ram.mem[3] = 8'd0;   // x[3] = 0
        dut.u_ram.mem[4] = 8'd0;   // x[4] = 0
        dut.u_ram.mem[5] = 8'd0;   // x[5] = 0
        dut.u_ram.mem[6] = 8'd0;   // x[6] = 0
        dut.u_ram.mem[7] = 8'd0;   // x[7] = 0
        
        // Initialize y[0-7] at addresses 8-15
        dut.u_ram.mem[8]  = 8'd4;  // y[0] = 4
        dut.u_ram.mem[9]  = 8'd2;  // y[1] = 2
        dut.u_ram.mem[10] = 8'd0;  // y[2] = 0
        dut.u_ram.mem[11] = 8'd0;  // y[3] = 0
        dut.u_ram.mem[12] = 8'd0;  // y[4] = 0
        dut.u_ram.mem[13] = 8'd0;  // y[5] = 0
        dut.u_ram.mem[14] = 8'd0;  // y[6] = 0
        dut.u_ram.mem[15] = 8'd0;  // y[7] = 0
        
        // h[0-7] at addresses 16-23 (will be computed)
        for (i = 16; i < 24; i = i + 1)
            dut.u_ram.mem[i] = 8'd0;
    end
    
    // PC management and instruction fetch
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 8'd0;
            ldi_pending <= 1'b0;
            halted <= 1'b0;
        end
        else if (!halted) begin
            // Check for LDI instruction (opcode 1000)
            if (instr[7:4] == 4'b1000 && !ldi_pending) begin
                ldi_pending <= 1'b1;
                pc <= pc + 8'd1;  // Move to immediate byte
            end
            else if (ldi_pending) begin
                ldi_pending <= 1'b0;
                pc <= pc + 8'd1;  // Move past immediate byte
            end
            else if (instr[7:4] == 4'b1111) begin
                // HLT instruction
                halted <= 1'b1;
            end
            else begin
                pc <= pc + 8'd1;
            end
        end
    end
    
    // Feed instruction from program memory
    always @(*) begin
        instr = prog_mem[pc];
    end
    
    // Main test sequence
    initial begin
        // Initialize
        done = 0;
        rst = 1;
        instr = 8'h00;  // NOP during reset
        
        // Generate VCD file for waveform viewing
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
        
        // Wait for reset
        repeat(5) @(posedge clk);
        rst = 0;
        
        $display("============================================");
        $display("Bit-Trix CPU Deconvolution Test - ISA v6");
        $display("============================================");
        
        // Display initial memory contents
        $display("\nInitial Memory Contents:");
        $display("x[0-7] (addr 0-7):");
        for (i = 0; i < 8; i = i + 1) begin
            $display("  x[%0d] = %0d", i, $signed(dut.u_ram.mem[i]));
        end
        
        $display("y[0-7] (addr 8-15):");
        for (i = 0; i < 8; i = i + 1) begin
            $display("  y[%0d] = %0d", i, $signed(dut.u_ram.mem[8+i]));
        end
        
        $display("\n--- Starting Execution ---");
        
        // Wait for halt or timeout
        cycle = 0;
        while (!done && cycle < 2000) begin
            @(posedge clk);
            cycle = cycle + 1;
            
            // Debug output every 50 cycles
            if (cycle % 50 == 0) begin
                $display("Cycle %4d: PC=%3d R0=%4d R1=%4d R2=%4d R3=%4d", 
                    cycle, pc, 
                    $signed(dut.regs[0]),
                    $signed(dut.regs[1]),
                    $signed(dut.regs[2]),
                    $signed(dut.regs[3]));
            end
            
            if (halted) begin
                $display("\n>>> CPU Halted after %0d cycles <<<", cycle);
                done = 1;
            end
        end
        
        if (!done) begin
            $display("\n>>> TIMEOUT: CPU did not halt within 2000 cycles <<<");
        end
        
        // Allow a few more cycles for final writes
        repeat(5) @(posedge clk);
        
        // Display computed h[n] values
        $display("\n============================================");
        $display("Computed h[0-7] (addr 16-23):");
        for (i = 0; i < 8; i = i + 1) begin
            $display("  h[%0d] = %4d (0x%02h)", i, $signed(dut.u_ram.mem[16+i]), dut.u_ram.mem[16+i]);
        end
        
        // Display register contents
        $display("\nFinal Register Contents:");
        $display("  R0 = %4d (0x%02h)", $signed(dut.regs[0]), dut.regs[0]);
        $display("  R1 = %4d (0x%02h)", $signed(dut.regs[1]), dut.regs[1]);
        $display("  R2 = %4d (0x%02h)", $signed(dut.regs[2]), dut.regs[2]);
        $display("  R3 = %4d (0x%02h)", $signed(dut.regs[3]), dut.regs[3]);
        
        // Verify results for this test case
        // Expected: h = [2, 1, 0, 0, 0, 0, 0, 0]
        $display("\n============================================");
        $display("Expected: h = [2, 1, 0, 0, 0, 0, 0, 0]");
        $display("Total cycles: %0d", cycle);
        $display("Program size: 226 bytes");
        $display("============================================");
        
        #100;
        $finish;
    end

endmodule
