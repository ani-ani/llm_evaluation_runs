module basic_interpreter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] instruction_mem [0:15],
    output reg [7:0] output_char,
    output reg output_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FETCH = 3'd1;
    localparam [2:0] DECODE = 3'd2;
    localparam [2:0] EXECUTE = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    // Operation codes
    localparam [7:0] OP_LET = 8'd0;
    localparam [7:0] OP_IF = 8'd1;
    localparam [7:0] OP_PRINT = 8'd2;
    localparam [7:0] OP_PRINTLN = 8'd3;

    // Condition codes
    localparam [2:0] COND_EQ = 3'd0;
    localparam [2:0] COND_LT = 3'd1;
    localparam [2:0] COND_GT = 3'd2;
    localparam [2:0] COND_NE = 3'd3;
    localparam [2:0] COND_LE = 3'd4;
    localparam [2:0] COND_GE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] pc, next_pc;
    reg [63:0] current_instr;
    reg [7:0] opcode;
    reg [7:0] operand_id;
    reg [31:0] data;
    reg [15:0] target_label;
    reg signed [15:0] regs [0:25]; // 26 variables (A-Z)
    reg [3:0] instr_index; // For PRINT execution
    reg [3:0] counter; // For multi-cycle operations
    reg [7:0] max_pc; // Track program length

    // For LET operations
    reg signed [15:0] op1, op2, result;
    reg [1:0] let_stage; // 0: read, 1: compute, 2: write

    // For IF operations
    reg condition_met;

    // Variable for PRINT/PRINTLN
    wire [7:0] string_char;
    assign string_char = data[7:0]; // Extract from data field

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pc <= 4'd0;
            current_instr <= 64'd0;
            opcode <= 8'd0;
            operand_id <= 8'd0;
            data <= 32'd0;
            target_label <= 16'd0;
            instr_index <= 4'd0;
            counter <= 4'd0;
            output_char <= 8'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
            let_stage <= 2'd0;
            max_pc <= 8'd15;
            // Initialize registers
            regs[0] <= 16'd0; regs[1] <= 16'd0; regs[2] <= 16'd0; regs[3] <= 16'd0;
            regs[4] <= 16'd0; regs[5] <= 16'd0; regs[6] <= 16'd0; regs[7] <= 16'd0;
            regs[8] <= 16'd0; regs[9] <= 16'd0; regs[10] <= 16'd0; regs[11] <= 16'd0;
            regs[12] <= 16'd0; regs[13] <= 16'd0; regs[14] <= 16'd0; regs[15] <= 16'd0;
            regs[16] <= 16'd0; regs[17] <= 16'd0; regs[18] <= 16'd0; regs[19] <= 16'd0;
            regs[20] <= 16'd0; regs[21] <= 16'd0; regs[22] <= 16'd0; regs[23] <= 16'd0;
            regs[24] <= 16'd0; regs[25] <= 16'd0;
        end else begin
            state <= next_state;
            pc <= next_pc;
            current_instr <= current_instr;
            opcode <= opcode;
            operand_id <= operand_id;
            data <= data;
            target_label <= target_label;
            instr_index <= instr_index;
            counter <= counter;
            output_char <= output_char;
            output_valid <= output_valid;
            done <= done;
            let_stage <= let_stage;
            max_pc <= max_pc;

            case (state)
                IDLE: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        pc <= 4'd0;
                        max_pc <= 4'd15;
                    end
                end
                FETCH: begin
                    if (pc <= 4'd15) begin
                        current_instr <= instruction_mem[pc];
                    end
                end
                DECODE: begin
                    opcode <= current_instr[7:0];
                    operand_id <= current_instr[15:8];
                    data <= current_instr[47:16];
                    target_label <= current_instr[63:48];
                end
                EXECUTE: begin
                    output_valid <= 1'b0;
                    case (opcode)
                        OP_LET: begin
                            case (let_stage)
                                2'd0: begin // Read operands
                                    // Op1 is operand_id[4:0] (A=0, B=1...)
                                    op1 <= regs[operand_id[4:0]];
                                    // Op2 is data[15:0] (literal) or regs[data[7:5]] (if bit 8 is set?)
                                    // Spec says: data (literal values or string indices)
                                    // For simplicity, op2 is always literal in data[15:0]
                                    op2 <= $signed(data[15:0]);
                                    let_stage <= 2'd1;
                                end
                                2'd1: begin // Compute
                                    case (data[23:16]) // Operator code in higher byte of data
                                        8'd0: result <= op1 + op2;
                                        8'd1: result <= op1 - op2;
                                        8'd2: result <= op1 * op2;
                                        8'd3: result <= (op2 != 0) ? (op1 / op2) : 16'd0;
                                        default: result <= 16'd0;
                                    endcase
                                    let_stage <= 2'd2;
                                end
                                2'd2: begin // Write back
                                    regs[operand_id[4:0]] <= result;
                                    let_stage <= 2'd0;
                                end
                            endcase
                        end
                        OP_IF: begin
                            // Read operands from registers (operand_id is op1 ID, data[7:0] is op2 ID)
                            // Spec: Compare two 16-bit values (var or literal)
                            // Let's assume operand_id is var1, data[7:0] is var2 (0-25), or literal if specified
                            // For this impl: operand_id = var1, data[7:0] = var2 (index)
                            op1 <= regs[operand_id[4:0]];
                            op2 <= regs[data[7:0]];
                            // Condition code is data[10:8]
                            case (data[10:8])
                                COND_EQ: condition_met <= (regs[operand_id[4:0]] == regs[data[7:0]]);
                                COND_LT: condition_met <= (regs[operand_id[4:0]] < regs[data[7:0]]);
                                COND_GT: condition_met <= (regs[operand_id[4:0]] > regs[data[7:0]]);
                                COND_NE: condition_met <= (regs[operand_id[4:0]] != regs[data[7:0]]);
                                COND_LE: condition_met <= (regs[operand_id[4:0]] <= regs[data[7:0]]);
                                COND_GE: condition_met <= (regs[operand_id[4:0]] >= regs[data[7:0]]);
                                default: condition_met <= 1'b0;
                            endcase
                        end
                        OP_PRINT, OP_PRINTLN: begin
                            if (instr_index < 4'd8) begin
                                output_char <= data[(instr_index * 8) +: 8];
                                output_valid <= 1'b1;
                                instr_index <= instr_index + 4'd1;
                            end
                            if (opcode == OP_PRINTLN && instr_index == 4'd7) begin
                                // Output newline after string
                                output_char <= 8'h0A;
                                output_valid <= 1'b1;
                            end
                        end
                    endcase
                end
                COMPLETE: begin
                    done <= 1'b1;
                    output_valid <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_pc = pc;
        
        case (state)
            IDLE: begin
                if (start) next_state = FETCH;
            end
            
            FETCH: begin
                next_state = DECODE;
            end
            
            DECODE: begin
                next_state = EXECUTE;
            end
            
            EXECUTE: begin
                case (opcode)
                    OP_LET: begin
                        if (let_stage == 2'd2) begin
                            next_state = COMPLETE;
                        end
                    end
                    OP_IF: begin
                        if (condition_met) begin
                            next_pc = target_label[3:0];
                        end else begin
                            next_pc = pc + 4'd1;
                        end
                        next_state = COMPLETE;
                    end
                    OP_PRINT, OP_PRINTLN: begin
                        if (instr_index >= 4'd8) begin
                            next_state = COMPLETE;
                            if (opcode == OP_PRINTLN) begin
                                // Extra cycle for newline
                                next_state = EXECUTE;
                                if (instr_index == 4'd9) next_state = COMPLETE;
                            end
                        end
                    end
                    default: next_state = COMPLETE;
                endcase
            end
            
            COMPLETE: begin
                next_state = FETCH;
                if (pc > 4'd14) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule