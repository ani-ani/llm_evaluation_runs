module correct_bracketing (
    input clk,
    input rst_n,
    input start,
    input [127:0] brackets,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam CHECK_CHAR = 2'b01;
    localparam VALIDATE = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] char_idx; // Counter for 16 characters (0-15)
    reg signed [5:0] balance; // Balance counter, range -16 to +16
    reg result_reg; // Internal result register

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_CHAR;
                else
                    next_state = IDLE;
            end
            CHECK_CHAR: begin
                // Process character 0 (index 0) through character 15 (index 15)
                if (char_idx < 4'd15)
                    next_state = CHECK_CHAR;
                else
                    next_state = VALIDATE; // Index 15 processed, move to validate
            end
            VALIDATE: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                if (start) // Stall in DONE if start is held high, wait for low pulse
                    next_state = DONE_STATE;
                else
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_idx <= 4'd0;
            balance <= 6'sd0;
            result_reg <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        char_idx <= 4'd0;
                        balance <= 6'sd0;
                        result_reg <= 1'b1; // Assume valid until proven invalid
                        done <= 1'b0;
                    end
                end

                CHECK_CHAR: begin
                    // Check if balance went negative in previous cycle or currently
                    if (balance < 0) begin
                        result_reg <= 1'b0;
                    end

                    // Extract current character (8 bits)
                    // brackets[127:120] is char 0, brackets[119:112] is char 1, etc.
                    // Index i corresponds to bits [127-8*i : 120-8*i]
                    case (char_idx)
                        4'd0: if (brackets[127:120] == 8'h28) balance <= balance + 1;
                                 else if (brackets[127:120] == 8'h29) balance <= balance - 1;
                        4'd1: if (brackets[119:112] == 8'h28) balance <= balance + 1;
                                 else if (brackets[119:112] == 8'h29) balance <= balance - 1;
                        4'd2: if (brackets[111:104] == 8'h28) balance <= balance + 1;
                                 else if (brackets[111:104] == 8'h29) balance <= balance - 1;
                        4'd3: if (brackets[103:96] == 8'h28) balance <= balance + 1;
                                 else if (brackets[103:96] == 8'h29) balance <= balance - 1;
                        4'd4: if (brackets[95:88] == 8'h28) balance <= balance + 1;
                                 else if (brackets[95:88] == 8'h29) balance <= balance - 1;
                        4'd5: if (brackets[87:80] == 8'h28) balance <= balance + 1;
                                 else if (brackets[87:80] == 8'h29) balance <= balance - 1;
                        4'd6: if (brackets[79:72] == 8'h28) balance <= balance + 1;
                                 else if (brackets[79:72] == 8'h29) balance <= balance - 1;
                        4'd7: if (brackets[71:64] == 8'h28) balance <= balance + 1;
                                 else if (brackets[71:64] == 8'h29) balance <= balance - 1;
                        4'd8: if (brackets[63:56] == 8'h28) balance <= balance + 1;
                                 else if (brackets[63:56] == 8'h29) balance <= balance - 1;
                        4'd9: if (brackets[55:48] == 8'h28) balance <= balance + 1;
                                 else if (brackets[55:48] == 8'h29) balance <= balance - 1;
                        4'd10: if (brackets[47:40] == 8'h28) balance <= balance + 1;
                                 else if (brackets[47:40] == 8'h29) balance <= balance - 1;
                        4'd11: if (brackets[39:32] == 8'h28) balance <= balance + 1;
                                 else if (brackets[39:32] == 8'h29) balance <= balance - 1;
                        4'd12: if (brackets[31:24] == 8'h28) balance <= balance + 1;
                                 else if (brackets[31:24] == 8'h29) balance <= balance - 1;
                        4'd13: if (brackets[23:16] == 8'h28) balance <= balance + 1;
                                 else if (brackets[23:16] == 8'h29) balance <= balance - 1;
                        4'd14: if (brackets[15:8] == 8'h28) balance <= balance + 1;
                                 else if (brackets[15:8] == 8'h29) balance <= balance - 1;
                        4'd15: if (brackets[7:0] == 8'h28) balance <= balance + 1;
                                 else if (brackets[7:0] == 8'h29) balance <= balance - 1;
                    endcase

                    if (char_idx < 4'd15) begin
                        char_idx <= char_idx + 1;
                    end
                end

                VALIDATE: begin
                    // Final check for balance == 0
                    if (balance != 0 || !result_reg) begin
                        result_reg <= 1'b0;
                    end else begin
                        result_reg <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    result <= result_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
