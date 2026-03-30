// ============================================================================
// Instruction Decoder for Bit-Trix CPU - ISA v6
// With MSUB (multiply-subtract) and SETLO (set to small immediate 0-3)
// ============================================================================
// ISA:
// 0000 NOP
// 0001 ADD    Rd = Rd + Rs2
// 0010 SETLO  Rd = imm2 (0-3, encoded in rs2 field)
// 0011 MSUB   R1 = R1 - Rd * Rs2 (multiply-subtract, implicit R1 dest)
// 0100 DIV    Rd = Rd / Rs2
// 0101 LOAD   Rd = RAM[Rs2]
// 0110 STORE  RAM[Rs2] = Rd
// 0111 MOV    Rd = Rs2
// 1000 LDI    Rd = imm8 (2-cycle)
// 1001 LOADHI Rd = RAM[16 + Rs2], then Rs2++ (h[] with auto-inc)
// 1010 LOADYI Rd = RAM[8 + Rs2]  (y[] access)
// 1011 STOREHI RAM[16 + Rs2] = Rd, then Rs2++ (h[] with auto-inc)
// 1100 INC    Rd = Rd + 1
// 1101 CLR    Rd = 0
// 1110 DEC    Rd = Rd - 1  
// 1111 HLT    Halt
// ============================================================================

module instr_decoder (
    input  wire [7:0] instr,
    
    output wire [3:0] opcode,
    output wire [1:0] rd,
    output wire [1:0] rs1,
    output wire [1:0] rs2,
    
    output reg        reg_wr_en,
    output reg        ram_wr_en,
    output reg        alu_en,
    output reg        load_en,
    output reg        store_en,
    output reg        ldi_en,
    output reg        loadhi_en,    // LOADHI: RAM[16+Rs2], Rs2++
    output reg        loadyi_en,    // LOADYI: RAM[8+Rs2]
    output reg        storehi_en,   // STOREHI: RAM[16+Rs2], Rs2++
    output reg        setlo_en,     // SETLO: Rd = imm2
    output reg        msub_en,      // MSUB: R1 = R1 - Rd*Rs2
    output reg        inc_en,
    output reg        clr_en,
    output reg        dec_en,
    output reg        halt_en,
    output reg  [3:0] alu_op
);

    localparam OP_NOP     = 4'b0000;
    localparam OP_ADD     = 4'b0001;
    localparam OP_SETLO   = 4'b0010;
    localparam OP_MSUB    = 4'b0011;
    localparam OP_DIV     = 4'b0100;
    localparam OP_LOAD    = 4'b0101;
    localparam OP_STORE   = 4'b0110;
    localparam OP_MOV     = 4'b0111;
    localparam OP_LDI     = 4'b1000;
    localparam OP_LOADHI  = 4'b1001;
    localparam OP_LOADYI  = 4'b1010;
    localparam OP_STOREHI = 4'b1011;
    localparam OP_INC     = 4'b1100;
    localparam OP_CLR     = 4'b1101;
    localparam OP_DEC     = 4'b1110;
    localparam OP_HLT     = 4'b1111;

    localparam ALU_NOP  = 4'b0000;
    localparam ALU_ADD  = 4'b0001;
    localparam ALU_SUB  = 4'b0010;
    localparam ALU_MUL  = 4'b0011;
    localparam ALU_DIV  = 4'b0100;
    localparam ALU_PASS = 4'b1111;

    assign opcode = instr[7:4];
    assign rd     = instr[3:2];
    assign rs1    = instr[3:2];
    assign rs2    = instr[1:0];

    always @(*) begin
        reg_wr_en   = 1'b0;
        ram_wr_en   = 1'b0;
        alu_en      = 1'b0;
        load_en     = 1'b0;
        store_en    = 1'b0;
        ldi_en      = 1'b0;
        loadhi_en   = 1'b0;
        loadyi_en   = 1'b0;
        storehi_en  = 1'b0;
        setlo_en    = 1'b0;
        msub_en     = 1'b0;
        inc_en      = 1'b0;
        clr_en      = 1'b0;
        dec_en      = 1'b0;
        halt_en     = 1'b0;
        alu_op      = ALU_NOP;

        case (opcode)
            OP_NOP: ;

            OP_ADD: begin
                reg_wr_en = 1'b1;
                alu_en    = 1'b1;
                alu_op    = ALU_ADD;
            end

            OP_SETLO: begin
                reg_wr_en = 1'b1;
                setlo_en  = 1'b1;
            end

            OP_MSUB: begin
                reg_wr_en = 1'b1;
                msub_en   = 1'b1;
            end

            OP_DIV: begin
                reg_wr_en = 1'b1;
                alu_en    = 1'b1;
                alu_op    = ALU_DIV;
            end

            OP_LOAD: begin
                reg_wr_en = 1'b1;
                load_en   = 1'b1;
            end

            OP_STORE: begin
                ram_wr_en = 1'b1;
                store_en  = 1'b1;
            end

            OP_MOV: begin
                reg_wr_en = 1'b1;
                alu_en    = 1'b1;
                alu_op    = ALU_PASS;
            end

            OP_LDI: begin
                ldi_en = 1'b1;
            end

            OP_LOADHI: begin
                reg_wr_en = 1'b1;  // Write to Rd AND increment Rs2
                loadhi_en = 1'b1;
            end

            OP_LOADYI: begin
                reg_wr_en = 1'b1;
                loadyi_en = 1'b1;
            end

            OP_STOREHI: begin
                ram_wr_en  = 1'b1;
                storehi_en = 1'b1;
            end

            OP_INC: begin
                reg_wr_en = 1'b1;
                inc_en    = 1'b1;
            end

            OP_CLR: begin
                reg_wr_en = 1'b1;
                clr_en    = 1'b1;
            end

            OP_DEC: begin
                reg_wr_en = 1'b1;
                dec_en    = 1'b1;
            end

            OP_HLT: begin
                halt_en = 1'b1;
            end

            default: ;
        endcase
    end

endmodule
