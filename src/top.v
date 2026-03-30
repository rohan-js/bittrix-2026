// ============================================================================
// Top Module - 8-bit CPU for Bit-Trix Competition - ISA v6
// With MSUB (multiply-subtract) and SETLO (set to small immediate)
// ============================================================================

module top (
    input clk,
    input rst,
    input [7:0] instr,
    output reg [255:0] cycle_count
);

    // Decoder outputs
    wire [3:0] opcode;
    wire [1:0] rd, rs1, rs2;
    wire       reg_wr_en, ram_wr_en;
    wire       alu_en, load_en, store_en, ldi_en;
    wire       loadhi_en, loadyi_en, storehi_en;
    wire       setlo_en, msub_en;
    wire       inc_en, clr_en, dec_en, halt_en;
    wire [3:0] alu_op;

    // Register file wires
    wire [7:0] rs1_data, rs2_data;
    wire [7:0] r1_data;  // For MSUB (always uses R1 as accumulator)
    reg  [7:0] reg_wr_data;
    reg        reg_wr_en_actual;
    reg  [1:0] reg_wr_addr;
    
    // Second write port for auto-increment
    reg        reg_wr2_en;
    reg  [1:0] reg_wr2_addr;
    reg  [7:0] reg_wr2_data;

    // ALU wires
    wire signed [7:0] alu_result;
    wire signed [7:0] msub_result;
    wire        zero_flag;

    // RAM wires
    wire [7:0] ram_rd_data;
    reg  [7:0] ram_addr;

    // Pipeline for LOAD
    reg        load_pending;
    reg  [1:0] load_rd;
    reg        autoinc_pending;  // Need to increment rs2 after load
    reg  [1:0] autoinc_reg;

    // LDI state
    reg        ldi_pending;
    reg  [1:0] ldi_rd;

    // Halt
    reg halted;

    // RAM address computation
    always @(*) begin
        if (loadhi_en || storehi_en)
            ram_addr = 8'd16 + rs2_data;
        else if (loadyi_en)
            ram_addr = 8'd8 + rs2_data;
        else
            ram_addr = rs2_data;
    end

    // Decoder
    instr_decoder u_decoder (
        .instr      (instr),
        .opcode     (opcode),
        .rd         (rd),
        .rs1        (rs1),
        .rs2        (rs2),
        .reg_wr_en  (reg_wr_en),
        .ram_wr_en  (ram_wr_en),
        .alu_en     (alu_en),
        .load_en    (load_en),
        .store_en   (store_en),
        .ldi_en     (ldi_en),
        .loadhi_en  (loadhi_en),
        .loadyi_en  (loadyi_en),
        .storehi_en (storehi_en),
        .setlo_en   (setlo_en),
        .msub_en    (msub_en),
        .inc_en     (inc_en),
        .clr_en     (clr_en),
        .dec_en     (dec_en),
        .halt_en    (halt_en),
        .alu_op     (alu_op)
    );

    // Register file (modified to support second write)
    reg [7:0] regs [0:3];
    integer i;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1)
                regs[i] <= 8'b0;
        end else begin
            if (reg_wr_en_actual)
                regs[reg_wr_addr] <= reg_wr_data;
            if (reg_wr2_en)
                regs[reg_wr2_addr] <= reg_wr2_data;
        end
    end
    
    // Register reads
    wire [7:0] rs1_data_int, rs2_data_int;
    assign rs1_data_int = regs[rs1];
    assign rs2_data_int = regs[rs2];
    assign rs1_data = rs1_data_int;
    assign rs2_data = rs2_data_int;
    assign r1_data  = regs[1];  // R1 is always index 1

    // ALU - for MSUB, we pass rd_data as 'a' and rs2_data as 'b', with r1_data as accumulator
    alu u_alu (
        .alu_op      (alu_op),
        .a           (rs1_data),
        .b           (rs2_data),
        .acc         (r1_data),      // R1 is the accumulator for MSUB
        .rd_data     (rs1_data),     // Rd data for MSUB multiply
        .result      (alu_result),
        .msub_result (msub_result),
        .zero_flag   (zero_flag)
    );

    // RAM
    ram #(
        .DEPTH      (64),
        .ADDR_WIDTH (8)
    ) u_ram (
        .clk     (clk),
        .wr_en   (ram_wr_en && !halted && !ldi_pending),
        .addr    (ram_addr),
        .wr_data (rs1_data),
        .rd_data (ram_rd_data)
    );

    // LOAD pipeline
    wire any_load = load_en || loadhi_en || loadyi_en;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            load_pending    <= 1'b0;
            load_rd         <= 2'b0;
            autoinc_pending <= 1'b0;
            autoinc_reg     <= 2'b0;
        end
        else if (!halted && !ldi_pending) begin
            if (any_load) begin
                load_pending <= 1'b1;
                load_rd      <= rd;
                // Auto-increment for LOADHI
                autoinc_pending <= loadhi_en;
                autoinc_reg     <= rs2;
            end
            else begin
                load_pending    <= 1'b0;
                autoinc_pending <= 1'b0;
            end
        end
        else begin
            load_pending    <= 1'b0;
            autoinc_pending <= 1'b0;
        end
    end

    // LDI pipeline
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ldi_pending <= 1'b0;
            ldi_rd      <= 2'b0;
        end
        else if (!halted) begin
            if (ldi_en && !ldi_pending) begin
                ldi_pending <= 1'b1;
                ldi_rd      <= rd;
            end
            else if (ldi_pending) begin
                ldi_pending <= 1'b0;
            end
        end
    end

    // Halt
    always @(posedge clk or posedge rst) begin
        if (rst)
            halted <= 1'b0;
        else if (halt_en && !halted && !ldi_pending)
            halted <= 1'b1;
    end

    // Register writeback - FIXED: Allow current instruction's write during load_pending
    // Port 1 (reg_wr_en_actual): For loaded data OR current instruction
    // Port 2 (reg_wr2_en): For auto-increment OR STOREHI increment
    always @(*) begin
        reg_wr_en_actual = 1'b0;
        reg_wr_addr      = rd;
        reg_wr_data      = 8'b0;
        reg_wr2_en       = 1'b0;
        reg_wr2_addr     = 2'b0;
        reg_wr2_data     = 8'b0;

        if (halted) begin
            // No writes
        end
        else if (ldi_pending) begin
            reg_wr_en_actual = 1'b1;
            reg_wr_addr      = ldi_rd;
            reg_wr_data      = instr;
        end
        else if (load_pending) begin
            // Write loaded data to Rd via primary port
            reg_wr_en_actual = 1'b1;
            reg_wr_addr      = load_rd;
            reg_wr_data      = ram_rd_data;
            // Auto-increment the index register via secondary port
            if (autoinc_pending) begin
                reg_wr2_en   = 1'b1;
                reg_wr2_addr = autoinc_reg;
                reg_wr2_data = regs[autoinc_reg] + 8'd1;
            end
            // ALSO allow certain current instructions to execute on secondary port
            // if they don't conflict with auto-inc
            // NOTE: This overwrites the auto-inc if both write to same register!
            // Priority: current instruction > auto-inc (to fix the SETLO bug)
            if (setlo_en) begin
                reg_wr2_en   = 1'b1;
                reg_wr2_addr = rd;
                reg_wr2_data = {6'b0, rs2};
            end
            else if (inc_en) begin
                reg_wr2_en   = 1'b1;
                reg_wr2_addr = rd;
                reg_wr2_data = rs1_data + 8'd1;
            end
            else if (dec_en) begin
                reg_wr2_en   = 1'b1;
                reg_wr2_addr = rd;
                reg_wr2_data = rs1_data - 8'd1;
            end
            else if (clr_en) begin
                reg_wr2_en   = 1'b1;
                reg_wr2_addr = rd;
                reg_wr2_data = 8'b0;
            end
        end
        else if (storehi_en) begin
            // STOREHI: also increment Rs2 after store
            reg_wr2_en   = 1'b1;
            reg_wr2_addr = rs2;
            reg_wr2_data = rs2_data + 8'd1;
        end
        else if (setlo_en) begin
            // SETLO: Rd = imm2 (rs2 field contains 0-3)
            reg_wr_en_actual = 1'b1;
            reg_wr_addr      = rd;
            reg_wr_data      = {6'b0, rs2};  // Zero-extend rs2 (2 bits) to 8 bits
        end
        else if (msub_en) begin
            // MSUB: R1 = R1 - Rd * Rs2
            reg_wr_en_actual = 1'b1;
            reg_wr_addr      = 2'b01;  // Always write to R1
            reg_wr_data      = msub_result;
        end
        else if (inc_en) begin
            reg_wr_en_actual = 1'b1;
            reg_wr_addr      = rd;
            reg_wr_data      = rs1_data + 8'd1;
        end
        else if (dec_en) begin
            reg_wr_en_actual = 1'b1;
            reg_wr_addr      = rd;
            reg_wr_data      = rs1_data - 8'd1;
        end
        else if (clr_en) begin
            reg_wr_en_actual = 1'b1;
            reg_wr_addr      = rd;
            reg_wr_data      = 8'b0;
        end
        else if (alu_en) begin
            reg_wr_en_actual = 1'b1;
            reg_wr_addr      = rd;
            reg_wr_data      = alu_result;
        end
    end

    // Cycle counter (DO NOT MODIFY)
    always @(posedge clk or posedge rst) begin
        if (rst)
            cycle_count <= 256'b0;
        else
            cycle_count <= cycle_count + 1;
    end

endmodule
