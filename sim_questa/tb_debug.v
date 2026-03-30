`timescale 1ns/1ps
//============================================================================
// Debug Testbench - Trace Test 14 step by step
//============================================================================

module tb_debug;

    reg clk;
    reg rst;
    reg [7:0] instr;
    wire [255:0] cycle_count;
    
    top dut (
        .clk         (clk),
        .rst         (rst),
        .instr       (instr),
        .cycle_count (cycle_count)
    );
    
    reg [7:0] prog_mem [0:255];
    reg [7:0] pc;
    reg halted;
    reg ldi_pending;
    integer cycle;
    integer i;
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $readmemb("program.mem", prog_mem);
    end
    
    // Test 14 data
    initial begin
        // x = [2, 1, 0, 0, 0, 0, 0, 0]
        dut.u_ram.mem[0] = 8'd2;
        dut.u_ram.mem[1] = 8'd1;
        for (i = 2; i < 8; i = i + 1) dut.u_ram.mem[i] = 8'd0;
        
        // y = [6, 5, 1, 0, 0, 0, 0, 0]
        dut.u_ram.mem[8]  = 8'd6;
        dut.u_ram.mem[9]  = 8'd5;
        dut.u_ram.mem[10] = 8'd1;
        for (i = 11; i < 16; i = i + 1) dut.u_ram.mem[i] = 8'd0;
        
        // Clear h[]
        for (i = 16; i < 24; i = i + 1) dut.u_ram.mem[i] = 8'd0;
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 8'd0;
            ldi_pending <= 1'b0;
            halted <= 1'b0;
        end
        else if (!halted) begin
            if (instr[7:4] == 4'b1000 && !ldi_pending) begin
                ldi_pending <= 1'b1;
                pc <= pc + 8'd1;
            end
            else if (ldi_pending) begin
                ldi_pending <= 1'b0;
                pc <= pc + 8'd1;
            end
            else if (instr[7:4] == 4'b1111) begin
                halted <= 1'b1;
            end
            else begin
                pc <= pc + 8'd1;
            end
        end
    end
    
    always @(*) begin
        instr = prog_mem[pc];
    end
    
    // Detailed trace for first 100 cycles
    always @(posedge clk) begin
        if (!rst && cycle < 100) begin
            $display("C%3d PC=%3d I=%02h | R0=%4d R1=%4d R2=%4d R3=%4d | h[0]=%4d h[1]=%4d h[2]=%4d h[3]=%4d",
                cycle, pc, instr,
                $signed(dut.regs[0]), $signed(dut.regs[1]), 
                $signed(dut.regs[2]), $signed(dut.regs[3]),
                $signed(dut.u_ram.mem[16]), $signed(dut.u_ram.mem[17]),
                $signed(dut.u_ram.mem[18]), $signed(dut.u_ram.mem[19]));
        end
    end
    
    initial begin
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        
        $display("=== Test 14 Debug Trace ===");
        $display("x = [2, 1, 0, 0, 0, 0, 0, 0]");
        $display("y = [6, 5, 1, 0, 0, 0, 0, 0]");
        $display("Expected h = [3, 1, 0, 0, 0, 0, 0, 0]");
        $display("");
        
        cycle = 0;
        while (!halted && cycle < 300) begin
            @(posedge clk);
            cycle = cycle + 1;
        end
        
        repeat(5) @(posedge clk);
        
        $display("");
        $display("=== Final h[] values ===");
        for (i = 0; i < 8; i = i + 1)
            $display("h[%0d] = %0d", i, $signed(dut.u_ram.mem[16+i]));
        
        $finish;
    end

endmodule
