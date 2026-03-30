`timescale 1ns/1ps
//============================================================================
// Comprehensive Testbench for Bit-Trix CPU - ISA v6
// Multiple test cases including edge cases for rigorous verification
//============================================================================

module tb_top_comprehensive;

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
    integer i, j;
    integer cycle;
    integer test_num;
    integer pass_count;
    integer fail_count;
    reg done;
    reg halted;
    reg ldi_pending;
    reg test_passed;
    
    // Expected results storage
    reg signed [7:0] expected_h [0:7];
    reg signed [7:0] computed_h [0:7];
    
    // Test data storage
    reg signed [7:0] test_x [0:7];
    reg signed [7:0] test_y [0:7];
    
    // Load program from file
    initial begin
        $readmemb("program.mem", prog_mem);
    end
    
    // PC management and instruction fetch
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
    
    // Feed instruction from program memory
    always @(*) begin
        instr = prog_mem[pc];
    end
    
    // Task to load test data into RAM
    task load_test_data;
        input integer test_case;
        begin
            // Clear h[] area first
            for (i = 16; i < 24; i = i + 1)
                dut.u_ram.mem[i] = 8'd0;
            
            case (test_case)
                // ====================================================
                // TEST 1: Simple impulse (basic functionality)
                // x = [2, 0, 0, 0, 0, 0, 0, 0]
                // y = [4, 2, 0, 0, 0, 0, 0, 0]
                // h = [2, 1, 0, 0, 0, 0, 0, 0]
                // ====================================================
                1: begin
                    test_x[0]=2;  test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=4;  test_y[1]=2;  test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=2; expected_h[1]=1; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0; expected_h[5]=0; expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 2: Unit impulse response (h[n] = delta[n])
                // x = [1, 0, 0, 0, 0, 0, 0, 0]
                // y = [1, 0, 0, 0, 0, 0, 0, 0]
                // h = [1, 0, 0, 0, 0, 0, 0, 0]
                // ====================================================
                2: begin
                    test_x[0]=1;  test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=1;  test_y[1]=0;  test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=1; expected_h[1]=0; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0; expected_h[5]=0; expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 3: Constant gain system (h[n] = 3*delta[n])
                // x = [4, 0, 0, 0, 0, 0, 0, 0]
                // y = [12, 0, 0, 0, 0, 0, 0, 0]
                // h = [3, 0, 0, 0, 0, 0, 0, 0]
                // ====================================================
                3: begin
                    test_x[0]=4;  test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=12; test_y[1]=0;  test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=3; expected_h[1]=0; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0; expected_h[5]=0; expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 4: Two-tap filter h = [1, 1, 0, 0, 0, 0, 0, 0]
                // x = [2, 0, 0, 0, 0, 0, 0, 0]
                // y = [2, 2, 0, 0, 0, 0, 0, 0] (convolution of x and h)
                // h = [1, 1, 0, 0, 0, 0, 0, 0]
                // ====================================================
                4: begin
                    test_x[0]=2;  test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=2;  test_y[1]=2;  test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=1; expected_h[1]=1; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0; expected_h[5]=0; expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 5: Negative impulse response
                // x = [2, 0, 0, 0, 0, 0, 0, 0]
                // y = [-4, 2, 0, 0, 0, 0, 0, 0]
                // h = [-2, 1, 0, 0, 0, 0, 0, 0]
                // ====================================================
                5: begin
                    test_x[0]=2;  test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=-4; test_y[1]=2;  test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=-2; expected_h[1]=1; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0;  expected_h[5]=0; expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 6: All negative values
                // x = [2, 0, 0, 0, 0, 0, 0, 0]
                // y = [-6, -4, -2, 0, 0, 0, 0, 0]
                // h = [-3, -2, -1, 0, 0, 0, 0, 0]
                // ====================================================
                6: begin
                    test_x[0]=2;  test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=-6; test_y[1]=-4; test_y[2]=-2; test_y[3]=0;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=-3; expected_h[1]=-2; expected_h[2]=-1; expected_h[3]=0;
                    expected_h[4]=0;  expected_h[5]=0;  expected_h[6]=0;  expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 7: Three-tap filter with mixed signs
                // x = [3, 0, 0, 0, 0, 0, 0, 0]
                // y = [6, -3, 9, 0, 0, 0, 0, 0]
                // h = [2, -1, 3, 0, 0, 0, 0, 0]
                // ====================================================
                7: begin
                    test_x[0]=3;  test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=6;  test_y[1]=-3; test_y[2]=9;  test_y[3]=0;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=2;  expected_h[1]=-1; expected_h[2]=3;  expected_h[3]=0;
                    expected_h[4]=0;  expected_h[5]=0;  expected_h[6]=0;  expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 8: Full 8-tap impulse response
                // x = [1, 0, 0, 0, 0, 0, 0, 0]
                // y = [1, 2, 3, 4, 5, 6, 7, 8]
                // h = [1, 2, 3, 4, 5, 6, 7, 8]
                // ====================================================
                8: begin
                    test_x[0]=1;  test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=1;  test_y[1]=2;  test_y[2]=3;  test_y[3]=4;
                    test_y[4]=5;  test_y[5]=6;  test_y[6]=7;  test_y[7]=8;
                    expected_h[0]=1; expected_h[1]=2; expected_h[2]=3; expected_h[3]=4;
                    expected_h[4]=5; expected_h[5]=6; expected_h[6]=7; expected_h[7]=8;
                end
                
                // ====================================================
                // TEST 9: Larger x[0] with division
                // x = [10, 0, 0, 0, 0, 0, 0, 0]
                // y = [50, 30, 20, 10, 0, 0, 0, 0]
                // h = [5, 3, 2, 1, 0, 0, 0, 0]
                // ====================================================
                9: begin
                    test_x[0]=10; test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=50; test_y[1]=30; test_y[2]=20; test_y[3]=10;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=5; expected_h[1]=3; expected_h[2]=2; expected_h[3]=1;
                    expected_h[4]=0; expected_h[5]=0; expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 10: Edge case - maximum positive value (127)
                // x = [1, 0, 0, 0, 0, 0, 0, 0]
                // y = [127, 0, 0, 0, 0, 0, 0, 0]
                // h = [127, 0, 0, 0, 0, 0, 0, 0]
                // ====================================================
                10: begin
                    test_x[0]=1;   test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;   test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=127; test_y[1]=0;  test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;   test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=127; expected_h[1]=0; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0;   expected_h[5]=0; expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 11: Edge case - minimum negative value (-128)
                // x = [1, 0, 0, 0, 0, 0, 0, 0]
                // y = [-128, 0, 0, 0, 0, 0, 0, 0]
                // h = [-128, 0, 0, 0, 0, 0, 0, 0]
                // ====================================================
                11: begin
                    test_x[0]=1;    test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;    test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=-128; test_y[1]=0;  test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;    test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=-128; expected_h[1]=0; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0;    expected_h[5]=0; expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 12: Saturation test - multiplication overflow
                // x = [1, 0, 0, 0, 0, 0, 0, 0]
                // y = [100, -100, 0, 0, 0, 0, 0, 0]
                // h = [100, -100, 0, 0, 0, 0, 0, 0]
                // Note: h[1]*x[0] = -100*1 = -100, y[1] - (-100) = -100 + 100 = 0
                // ====================================================
                12: begin
                    test_x[0]=1;    test_x[1]=0;    test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;    test_x[5]=0;    test_x[6]=0;  test_x[7]=0;
                    test_y[0]=100;  test_y[1]=-100; test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;    test_y[5]=0;    test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=100;  expected_h[1]=-100; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0;    expected_h[5]=0;    expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 13: Division with negative x[0]
                // x = [-2, 0, 0, 0, 0, 0, 0, 0]
                // y = [-6, 4, 0, 0, 0, 0, 0, 0]
                // h = [3, -2, 0, 0, 0, 0, 0, 0]
                // h[0] = -6/-2 = 3
                // h[1] = (4 - 3*0) / -2 = 4/-2 = -2
                // ====================================================
                13: begin
                    test_x[0]=-2; test_x[1]=0;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=-6; test_y[1]=4;  test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=3;  expected_h[1]=-2; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0;  expected_h[5]=0;  expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 14: Non-trivial deconvolution
                // x = [2, 1, 0, 0, 0, 0, 0, 0]
                // h = [3, 1, 0, 0, 0, 0, 0, 0] (what we want to recover)
                // y = conv(x,h) = [6, 5, 1, 0, 0, 0, 0, 0]
                // y[0] = x[0]*h[0] = 2*3 = 6
                // y[1] = x[0]*h[1] + x[1]*h[0] = 2*1 + 1*3 = 5
                // y[2] = x[1]*h[1] = 1*1 = 1
                // ====================================================
                14: begin
                    test_x[0]=2;  test_x[1]=1;  test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=6;  test_y[1]=5;  test_y[2]=1;  test_y[3]=0;
                    test_y[4]=0;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=3; expected_h[1]=1; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0; expected_h[5]=0; expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 15: Complex multi-tap scenario
                // x = [4, 2, 1, 0, 0, 0, 0, 0]
                // h = [2, -1, 1, 0, 0, 0, 0, 0] (target)
                // y = conv(x,h):
                // y[0] = 4*2 = 8
                // y[1] = 4*(-1) + 2*2 = -4 + 4 = 0
                // y[2] = 4*1 + 2*(-1) + 1*2 = 4 - 2 + 2 = 4
                // y[3] = 2*1 + 1*(-1) = 2 - 1 = 1
                // y[4] = 1*1 = 1
                // ====================================================
                15: begin
                    test_x[0]=4;  test_x[1]=2;  test_x[2]=1;  test_x[3]=0;
                    test_x[4]=0;  test_x[5]=0;  test_x[6]=0;  test_x[7]=0;
                    test_y[0]=8;  test_y[1]=0;  test_y[2]=4;  test_y[3]=1;
                    test_y[4]=1;  test_y[5]=0;  test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=2;  expected_h[1]=-1; expected_h[2]=1; expected_h[3]=0;
                    expected_h[4]=0;  expected_h[5]=0;  expected_h[6]=0; expected_h[7]=0;
                end
                
                // ====================================================
                // TEST 16: Saturation in MSUB (multiply-subtract)
                // Testing when intermediate computation might overflow
                // x = [1, 0, 0, 0, 0, 0, 0, 0]
                // y = [120, 120, 0, 0, 0, 0, 0, 0]
                // h = [120, 120, 0, 0, 0, 0, 0, 0]
                // h[1] = (y[1] - h[0]*x[1]) / x[0] = (120 - 120*0) / 1 = 120
                // ====================================================
                16: begin
                    test_x[0]=1;   test_x[1]=0;   test_x[2]=0;  test_x[3]=0;
                    test_x[4]=0;   test_x[5]=0;   test_x[6]=0;  test_x[7]=0;
                    test_y[0]=120; test_y[1]=120; test_y[2]=0;  test_y[3]=0;
                    test_y[4]=0;   test_y[5]=0;   test_y[6]=0;  test_y[7]=0;
                    expected_h[0]=120; expected_h[1]=120; expected_h[2]=0; expected_h[3]=0;
                    expected_h[4]=0;   expected_h[5]=0;   expected_h[6]=0; expected_h[7]=0;
                end
                
                default: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        test_x[i] = 0;
                        test_y[i] = 0;
                        expected_h[i] = 0;
                    end
                end
            endcase
            
            // Load test data into RAM
            for (i = 0; i < 8; i = i + 1) begin
                dut.u_ram.mem[i] = test_x[i];
                dut.u_ram.mem[8+i] = test_y[i];
            end
        end
    endtask
    
    // Task to run a single test case
    task run_test;
        input integer test_case;
        begin
            // Load test data
            load_test_data(test_case);
            
            // Reset the CPU
            rst = 1;
            repeat(5) @(posedge clk);
            rst = 0;
            
            // Wait for halt or timeout
            cycle = 0;
            while (!halted && cycle < 2000) begin
                @(posedge clk);
                cycle = cycle + 1;
            end
            
            // Allow a few more cycles for final writes
            repeat(5) @(posedge clk);
            
            // Read computed results
            for (i = 0; i < 8; i = i + 1) begin
                computed_h[i] = dut.u_ram.mem[16+i];
            end
            
            // Compare results
            test_passed = 1;
            for (i = 0; i < 8; i = i + 1) begin
                if (computed_h[i] !== expected_h[i]) begin
                    test_passed = 0;
                end
            end
        end
    endtask
    
    // Task to print test results
    task print_test_result;
        input integer test_case;
        begin
            $display("\n--- Test Case %0d ---", test_case);
            $display("Input x[n]:    [%4d, %4d, %4d, %4d, %4d, %4d, %4d, %4d]",
                $signed(test_x[0]), $signed(test_x[1]), $signed(test_x[2]), $signed(test_x[3]),
                $signed(test_x[4]), $signed(test_x[5]), $signed(test_x[6]), $signed(test_x[7]));
            $display("Input y[n]:    [%4d, %4d, %4d, %4d, %4d, %4d, %4d, %4d]",
                $signed(test_y[0]), $signed(test_y[1]), $signed(test_y[2]), $signed(test_y[3]),
                $signed(test_y[4]), $signed(test_y[5]), $signed(test_y[6]), $signed(test_y[7]));
            $display("Expected h[n]: [%4d, %4d, %4d, %4d, %4d, %4d, %4d, %4d]",
                $signed(expected_h[0]), $signed(expected_h[1]), $signed(expected_h[2]), $signed(expected_h[3]),
                $signed(expected_h[4]), $signed(expected_h[5]), $signed(expected_h[6]), $signed(expected_h[7]));
            $display("Computed h[n]: [%4d, %4d, %4d, %4d, %4d, %4d, %4d, %4d]",
                $signed(computed_h[0]), $signed(computed_h[1]), $signed(computed_h[2]), $signed(computed_h[3]),
                $signed(computed_h[4]), $signed(computed_h[5]), $signed(computed_h[6]), $signed(computed_h[7]));
            $display("Cycles: %0d", cycle);
            
            if (test_passed) begin
                $display("Result: PASS");
                pass_count = pass_count + 1;
            end
            else begin
                $display("Result: *** FAIL ***");
                fail_count = fail_count + 1;
                // Show which elements differ
                for (i = 0; i < 8; i = i + 1) begin
                    if (computed_h[i] !== expected_h[i]) begin
                        $display("  MISMATCH at h[%0d]: expected %0d, got %0d", 
                            i, $signed(expected_h[i]), $signed(computed_h[i]));
                    end
                end
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize
        done = 0;
        rst = 1;
        instr = 8'h00;
        pass_count = 0;
        fail_count = 0;
        
        // Generate VCD file
        $dumpfile("tb_top_comprehensive.vcd");
        $dumpvars(0, tb_top_comprehensive);
        
        $display("================================================================");
        $display("     Bit-Trix CPU - Comprehensive Functionality Test Suite");
        $display("                        ISA v6");
        $display("================================================================");
        $display("Program size: 226 bytes");
        $display("Testing deconvolution: h[n] = DECONV(y[n], x[n])");
        $display("================================================================");
        
        // Run all test cases
        for (test_num = 1; test_num <= 16; test_num = test_num + 1) begin
            run_test(test_num);
            print_test_result(test_num);
        end
        
        // Summary
        $display("\n================================================================");
        $display("                      TEST SUMMARY");
        $display("================================================================");
        $display("Total Tests:  %0d", pass_count + fail_count);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d", fail_count);
        $display("================================================================");
        
        if (fail_count == 0) begin
            $display("           *** ALL TESTS PASSED! ***");
        end
        else begin
            $display("           *** SOME TESTS FAILED! ***");
        end
        $display("================================================================\n");
        
        #100;
        $finish;
    end

endmodule
