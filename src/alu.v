// ============================================================================
// ALU Module - Arithmetic Logic Unit for ISA v6
// Supports: ADD, DIV, PASS, MSUB (R1 = R1 - Rd*Rs2)
// Uses signed saturation arithmetic (clamp to -128/+127)
// ============================================================================

module alu (
    input  wire [3:0] alu_op,       // ALU operation select
    input  wire signed [7:0] a,     // Operand A (signed) - rs1_data (Rd for MSUB)
    input  wire signed [7:0] b,     // Operand B (signed) - rs2_data
    input  wire signed [7:0] acc,   // Accumulator input for MSUB (R1 data)
    input  wire signed [7:0] rd_data, // Rd data (same as a, but explicit)
    output reg  signed [7:0] result,// Result (signed, saturated)
    output reg  signed [7:0] msub_result, // MSUB result: acc - rd_data*b
    output wire zero_flag           // Zero flag
);

    // ALU Operation Codes (must match instr_decoder)
    localparam ALU_NOP  = 4'b0000;
    localparam ALU_ADD  = 4'b0001;
    localparam ALU_SUB  = 4'b0010;  // Not used in ISA v6, kept for compatibility
    localparam ALU_MUL  = 4'b0011;  // Not used in ISA v6
    localparam ALU_DIV  = 4'b0100;
    localparam ALU_PASS = 4'b1111;  // Pass through B (for MOV)

    // Intermediate results (wider for overflow detection)
    reg signed [15:0] temp_result;
    reg signed [15:0] temp_msub;
    
    // Saturation limits for signed 8-bit
    localparam signed [7:0] SAT_MAX = 8'sd127;   // +127
    localparam signed [7:0] SAT_MIN = -8'sd128;  // -128

    // Zero flag
    assign zero_flag = (result == 8'b0);

    // Saturation function
    function signed [7:0] saturate;
        input signed [15:0] val;
        begin
            if (val > SAT_MAX)
                saturate = SAT_MAX;
            else if (val < SAT_MIN)
                saturate = SAT_MIN;
            else
                saturate = val[7:0];
        end
    endfunction

    // Combinational ALU logic
    always @(*) begin
        temp_result = 16'sd0;
        result = 8'sd0;

        case (alu_op)
            ALU_NOP: begin
                result = 8'sd0;
            end

            ALU_ADD: begin
                temp_result = a + b;
                result = saturate(temp_result);
            end

            ALU_SUB: begin
                temp_result = a - b;
                result = saturate(temp_result);
            end

            ALU_MUL: begin
                temp_result = a * b;
                result = saturate(temp_result);
            end

            ALU_DIV: begin
                // Division with divide-by-zero protection
                if (b == 8'sd0)
                    result = (a >= 0) ? SAT_MAX : SAT_MIN;
                else
                    result = a / b;
            end

            ALU_PASS: begin
                // Pass through B (for MOV: Rd = Rs2)
                result = b;
            end

            default: begin
                result = 8'sd0;
            end
        endcase
    end

    // MSUB computation: acc - rd_data * b (always computed for MSUB instruction)
    // Used for deconvolution inner loop: R1 = R1 - h[k] * x[n-k]
    // rd_data = h[k] (from Rd field), b = x[n-k] (from Rs2 field), acc = R1
    always @(*) begin
        temp_msub = acc - (rd_data * b);
        msub_result = saturate(temp_msub);
    end

endmodule
