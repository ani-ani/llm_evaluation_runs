module ParenthesesChecker(
    input clk,
    input rst_n,
    input start,
    input [3:0] str1_len,
    input [7:0] str1_char_0,
    input [7:0] str1_char_1,
    input [7:0] str1_char_2,
    input [7:0] str1_char_3,
    input [7:0] str1_char_4,
    input [7:0] str1_char_5,
    input [7:0] str1_char_6,
    input [7:0] str1_char_7,
    input [7:0] str1_char_8,
    input [7:0] str1_char_9,
    input [7:0] str1_char_10,
    input [7:0] str1_char_11,
    input [7:0] str1_char_12,
    input [7:0] str1_char_13,
    input [7:0] str1_char_14,
    input [7:0] str1_char_15,
    input [3:0] str2_len,
    input [7:0] str2_char_0,
    input [7:0] str2_char_1,
    input [7:0] str2_char_2,
    input [7:0] str2_char_3,
    input [7:0] str2_char_4,
    input [7:0] str2_char_5,
    input [7:0] str2_char_6,
    input [7:0] str2_char_7,
    input [7:0] str2_char_8,
    input [7:0] str2_char_9,
    input [7:0] str2_char_10,
    input [7:0] str2_char_11,
    input [7:0] str2_char_12,
    input [7:0] str2_char_13,
    input [7:0] str2_char_14,
    input [7:0] str2_char_15,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_STR1_STR2 = 3'd1;
    localparam [2:0] CHECK_STR2_STR1 = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Balance tracking
    reg signed [4:0] balance;
    reg negative_flag;

    // String processing
    reg [4:0] char_index;
    reg [3:0] current_len;
    reg [7:0] current_char;
    reg check_order; // 0: str1+str2, 1: str2+str1
    reg [3:0] str1_pos;
    reg [3:0] str2_pos;

    // Result tracking
    reg str1_str2_valid;
    reg str2_str1_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            balance <= 5'd0;
            negative_flag <= 1'b0;
            char_index <= 5'd0;
            current_len <= 4'd0;
            current_char <= 8'd0;
            check_order <= 1'b0;
            str1_pos <= 4'd0;
            str2_pos <= 4'd0;
            str1_str2_valid <= 1'b0;
            str2_str1_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK_STR1_STR2;
                        balance <= 5'd0;
                        negative_flag <= 1'b0;
                        char_index <= 5'd0;
                        str1_pos <= 4'd0;
                        str2_pos <= 4'd0;
                        check_order <= 1'b0;
                        str1_str2_valid <= 1'b0;
                        str2_str1_valid <= 1'b0;
                    end
                end

                CHECK_STR1_STR2: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process characters
                    if (char_index < str1_len) begin
                        // Get character from str1
                        case (char_index)
                            5'd0: current_char <= str1_char_0;
                            5'd1: current_char <= str1_char_1;
                            5'd2: current_char <= str1_char_2;
                            5'd3: current_char <= str1_char_3;
                            5'd4: current_char <= str1_char_4;
                            5'd5: current_char <= str1_char_5;
                            5'd6: current_char <= str1_char_6;
                            5'd7: current_char <= str1_char_7;
                            5'd8: current_char <= str1_char_8;
                            5'd9: current_char <= str1_char_9;
                            5'd10: current_char <= str1_char_10;
                            5'd11: current_char <= str1_char_11;
                            5'd12: current_char <= str1_char_12;
                            5'd13: current_char <= str1_char_13;
                            5'd14: current_char <= str1_char_14;
                            5'd15: current_char <= str1_char_15;
                            default: current_char <= 8'd0;
                        endcase
                        str1_pos <= str1_pos + 4'd1;
                    end else if (char_index < (str1_len + str2_len)) begin
                        // Get character from str2
                        case (char_index - str1_len)
                            5'd0: current_char <= str2_char_0;
                            5'd1: current_char <= str2_char_1;
                            5'd2: current_char <= str2_char_2;
                            5'd3: current_char <= str2_char_3;
                            5'd4: current_char <= str2_char_4;
                            5'd5: current_char <= str2_char_5;
                            5'd6: current_char <= str2_char_6;
                            5'd7: current_char <= str2_char_7;
                            5'd8: current_char <= str2_char_8;
                            5'd9: current_char <= str2_char_9;
                            5'd10: current_char <= str2_char_10;
                            5'd11: current_char <= str2_char_11;
                            5'd12: current_char <= str2_char_12;
                            5'd13: current_char <= str2_char_13;
                            5'd14: current_char <= str2_char_14;
                            5'd15: current_char <= str2_char_15;
                            default: current_char <= 8'd0;
                        endcase
                        str2_pos <= str2_pos + 4'd1;
                    end

                    // Update balance
                    if (current_char == 8'd40) begin // '('
                        balance <= balance + 5'd1;
                    end else if (current_char == 8'd41) begin // ')'
                        balance <= balance - 5'd1;
                        if (balance < 5'd0) begin
                            negative_flag <= 1'b1;
                        end
                    end

                    // Move to next character
                    char_index <= char_index + 5'd1;

                    // Check if done with this pass
                    if (char_index >= (str1_len + str2_len)) begin
                        // Check if this concatenation is valid
                        if (balance == 5'd0 && !negative_flag) begin
                            str1_str2_valid <= 1'b1;
                        end
                        
                        // Move to next check
                        state <= CHECK_STR2_STR1;
                        balance <= 5'd0;
                        negative_flag <= 1'b0;
                        char_index <= 5'd0;
                        str1_pos <= 4'd0;
                        str2_pos <= 4'd0;
                    end
                end

                CHECK_STR2_STR1: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process characters
                    if (char_index < str2_len) begin
                        // Get character from str2
                        case (char_index)
                            5'd0: current_char <= str2_char_0;
                            5'd1: current_char <= str2_char_1;
                            5'd2: current_char <= str2_char_2;
                            5'd3: current_char <= str2_char_3;
                            5'd4: current_char <= str2_char_4;
                            5'd5: current_char <= str2_char_5;
                            5'd6: current_char <= str2_char_6;
                            5'd7: current_char <= str2_char_7;
                            5'd8: current_char <= str2_char_8;
                            5'd9: current_char <= str2_char_9;
                            5'd10: current_char <= str2_char_10;
                            5'd11: current_char <= str2_char_11;
                            5'd12: current_char <= str2_char_12;
                            5'd13: current_char <= str2_char_13;
                            5'd14: current_char <= str2_char_14;
                            5'd15: current_char <= str2_char_15;
                            default: current_char <= 8'd0;
                        endcase
                        str2_pos <= str2_pos + 4'd1;
                    end else if (char_index < (str2_len + str1_len)) begin
                        // Get character from str1
                        case (char_index - str2_len)
                            5'd0: current_char <= str1_char_0;
                            5'd1: current_char <= str1_char_1;
                            5'd2: current_char <= str1_char_2;
                            5'd3: current_char <= str1_char_3;
                            5'd4: current_char <= str1_char_4;
                            5'd5: current_char <= str1_char_5;
                            5'd6: current_char <= str1_char_6;
                            5'd7: current_char <= str1_char_7;
                            5'd8: current_char <= str1_char_8;
                            5'd9: current_char <= str1_char_9;
                            5'd10: current_char <= str1_char_10;
                            5'd11: current_char <= str1_char_11;
                            5'd12: current_char <= str1_char_12;
                            5'd13: current_char <= str1_char_13;
                            5'd14: current_char <= str1_char_14;
                            5'd15: current_char <= str1_char_15;
                            default: current_char <= 8'd0;
                        endcase
                        str1_pos <= str1_pos + 4'd1;
                    end

                    // Update balance
                    if (current_char == 8'd40) begin // '('
                        balance <= balance + 5'd1;
                    end else if (current_char == 8'd41) begin // ')'
                        balance <= balance - 5'd1;
                        if (balance < 5'd0) begin
                            negative_flag <= 1'b1;
                        end
                    end

                    // Move to next character
                    char_index <= char_index + 5'd1;

                    // Check if done with this pass
                    if (char_index >= (str2_len + str1_len)) begin
                        // Check if this concatenation is valid
                        if (balance == 5'd0 && !negative_flag) begin
                            str2_str1_valid <= 1'b1;
                        end
                        
                        // Move to finish state
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Set result based on either check passing
                    result <= str1_str2_valid || str2_str1_valid;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule