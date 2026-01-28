module SubstringChecker (
    input clk,
    input rst_n,
    input start,
    input [7:0] str_0 [0:7],
    input [7:0] str_1 [0:7],
    input [7:0] str_2 [0:7],
    input [7:0] str_3 [0:7],
    input [7:0] str_4 [0:7],
    input [7:0] str_5 [0:7],
    input [7:0] str_6 [0:7],
    input [7:0] str_7 [0:7],
    input [7:0] str_8 [0:7],
    input [7:0] str_9 [0:7],
    input [7:0] str_10 [0:7],
    input [7:0] str_11 [0:7],
    input [7:0] str_12 [0:7],
    input [7:0] str_13 [0:7],
    input [7:0] str_14 [0:7],
    input [7:0] str_15 [0:7],
    input [7:0] sub_str [0:7],
    input [3:0] num_strings,
    input [3:0] sub_len,
    output reg found,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_STRING = 3'd1;
    localparam [2:0] COMPARE_CHAR = 3'd2;
    localparam [2:0] UPDATE_FOUND = 3'd3;
    localparam [2:0] NEXT_STRING = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] str_idx;
    reg [3:0] char_idx;
    reg [3:0] compare_idx;
    reg temp_found;
    reg [7:0] current_char;
    reg [7:0] sub_char;
    reg match_char;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found <= 1'b0;
            done <= 1'b0;
            str_idx <= 4'd0;
            char_idx <= 4'd0;
            compare_idx <= 4'd0;
            temp_found <= 1'b0;
            current_char <= 8'd0;
            sub_char <= 8'd0;
            match_char <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    temp_found <= 1'b0;
                    str_idx <= 4'd0;
                    char_idx <= 4'd0;
                    compare_idx <= 4'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK_STRING;
                    end
                end

                CHECK_STRING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (str_idx >= num_strings || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        char_idx <= 4'd0;
                        state <= COMPARE_CHAR;
                    end
                end

                COMPARE_CHAR: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_idx >= 8'd8 || cycle_count >= MAX_CYCLES) begin
                        state <= NEXT_STRING;
                    end else begin
                        compare_idx <= 4'd0;
                        case (str_idx)
                            4'd0: current_char <= str_0[char_idx];
                            4'd1: current_char <= str_1[char_idx];
                            4'd2: current_char <= str_2[char_idx];
                            4'd3: current_char <= str_3[char_idx];
                            4'd4: current_char <= str_4[char_idx];
                            4'd5: current_char <= str_5[char_idx];
                            4'd6: current_char <= str_6[char_idx];
                            4'd7: current_char <= str_7[char_idx];
                            4'd8: current_char <= str_8[char_idx];
                            4'd9: current_char <= str_9[char_idx];
                            4'd10: current_char <= str_10[char_idx];
                            4'd11: current_char <= str_11[char_idx];
                            4'd12: current_char <= str_12[char_idx];
                            4'd13: current_char <= str_13[char_idx];
                            4'd14: current_char <= str_14[char_idx];
                            4'd15: current_char <= str_15[char_idx];
                            default: current_char <= 8'd0;
                        endcase
                        state <= UPDATE_FOUND;
                    end
                end

                UPDATE_FOUND: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_char == 8'd0) begin
                        state <= NEXT_STRING;
                    end else if (sub_len > 4'd0 && char_idx + sub_len <= 4'd8) begin
                        if (current_char == sub_str[4'd0]) begin
                            match_char <= 1'b1;
                            compare_idx <= 4'd1;
                            state <= COMPARE_CHAR;
                        end else begin
                            state <= COMPARE_CHAR;
                        end
                    end else begin
                        state <= COMPARE_CHAR;
                    end
                end

                NEXT_STRING: begin
                    if (temp_found) begin
                        found <= 1'b1;
                        state <= FINISH;
                    end else begin
                        str_idx <= str_idx + 4'd1;
                        state <= CHECK_STRING;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule