module pattern_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] s_char_0,
    input [7:0] s_char_1,
    input [7:0] s_char_2,
    input [7:0] s_char_3,
    input [7:0] s_char_4,
    input [7:0] s_char_5,
    input [7:0] s_char_6,
    input [7:0] s_char_7,
    input [7:0] s_char_8,
    input [7:0] s_char_9,
    input [7:0] s_char_10,
    input [7:0] s_char_11,
    input [7:0] s_char_12,
    input [7:0] s_char_13,
    input [7:0] s_char_14,
    input [7:0] s_char_15,
    input [7:0] t_char_0,
    input [7:0] t_char_1,
    input [7:0] t_char_2,
    input [7:0] t_char_3,
    input [7:0] t_char_4,
    input [7:0] t_char_5,
    input [7:0] t_char_6,
    input [7:0] t_char_7,
    input [7:0] t_char_8,
    input [7:0] t_char_9,
    input [7:0] t_char_10,
    input [7:0] t_char_11,
    input [7:0] t_char_12,
    input [7:0] t_char_13,
    input [7:0] t_char_14,
    input [7:0] t_char_15,
    input [4:0] s_len,
    input [4:0] t_len,
    output reg result,
    output reg done
);

    // Local parameters for states
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] FIND_WILDCARD = 4'd1;
    localparam [3:0] CHECK_PREFIX = 4'd2;
    localparam [3:0] CHECK_SUFFIX = 4'd3;
    localparam [3:0] CHECK_NO_WILDCARD = 4'd4;
    localparam [3:0] FINISH = 4'd5;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] s_reg [0:15];
    reg [7:0] t_reg [0:15];
    reg [4:0] s_len_reg;
    reg [4:0] t_len_reg;
    reg [4:0] wild_pos; // Position of wildcard (0-15, or 16 if none)
    reg [4:0] prefix_len;
    reg [4:0] suffix_len;
    reg [4:0] i; // Loop counter
    reg result_reg;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd100;
    integer j;

    // State transition and synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            result_reg <= 1'b0;
            cycle_counter <= 8'd0;
            wild_pos <= 5'd16; // Default to no wildcard
            prefix_len <= 5'd0;
            suffix_len <= 5'd0;
            i <= 5'd0;
            for (j = 0; j < 16; j = j + 1) begin
                s_reg[j] <= 8'd0;
                t_reg[j] <= 8'd0;
            end
            s_len_reg <= 5'd0;
            t_len_reg <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    result_reg <= 1'b0;
                    cycle_counter <= 8'd0;
                    wild_pos <= 5'd16;
                    prefix_len <= 5'd0;
                    suffix_len <= 5'd0;
                    i <= 5'd0;
                    if (start) begin
                        // Capture inputs
                        s_reg[0] <= s_char_0;
                        s_reg[1] <= s_char_1;
                        s_reg[2] <= s_char_2;
                        s_reg[3] <= s_char_3;
                        s_reg[4] <= s_char_4;
                        s_reg[5] <= s_char_5;
                        s_reg[6] <= s_char_6;
                        s_reg[7] <= s_char_7;
                        s_reg[8] <= s_char_8;
                        s_reg[9] <= s_char_9;
                        s_reg[10] <= s_char_10;
                        s_reg[11] <= s_char_11;
                        s_reg[12] <= s_char_12;
                        s_reg[13] <= s_char_13;
                        s_reg[14] <= s_char_14;
                        s_reg[15] <= s_char_15;
                        t_reg[0] <= t_char_0;
                        t_reg[1] <= t_char_1;
                        t_reg[2] <= t_char_2;
                        t_reg[3] <= t_char_3;
                        t_reg[4] <= t_char_4;
                        t_reg[5] <= t_char_5;
                        t_reg[6] <= t_char_6;
                        t_reg[7] <= t_char_7;
                        t_reg[8] <= t_char_8;
                        t_reg[9] <= t_char_9;
                        t_reg[10] <= t_char_10;
                        t_reg[11] <= t_char_11;
                        t_reg[12] <= t_char_12;
                        t_reg[13] <= t_char_13;
                        t_reg[14] <= t_char_14;
                        t_reg[15] <= t_char_15;
                        s_len_reg <= s_len;
                        t_len_reg <= t_len;
                        state <= FIND_WILDCARD;
                    end
                end

                FIND_WILDCARD: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (i < s_len_reg) begin
                        if (s_reg[i] == 8'h2A) begin // ASCII '*' is 42 (0x2A)
                            wild_pos <= i;
                            prefix_len <= i;
                            suffix_len <= s_len_reg - i - 5'd1;
                            state <= CHECK_PREFIX;
                            i <= 5'd0; // Reset i for prefix check
                        end else begin
                            i <= i + 5'd1;
                        end
                    end else begin
                        // No wildcard found
                        wild_pos <= 5'd16;
                        state <= CHECK_NO_WILDCARD;
                        i <= 5'd0;
                    end
                end

                CHECK_NO_WILDCARD: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (s_len_reg != t_len_reg) begin
                        result_reg <= 1'b0;
                        state <= FINISH;
                    end else if (i < s_len_reg) begin
                        if (s_reg[i] != t_reg[i]) begin
                            result_reg <= 1'b0;
                            state <= FINISH;
                        end else begin
                            i <= i + 5'd1;
                        end
                    end else begin
                        result_reg <= 1'b1;
                        state <= FINISH;
                    end
                end

                CHECK_PREFIX: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Check condition a: prefix_len + suffix_len <= t_len
                    if (prefix_len + suffix_len > t_len_reg) begin
                        result_reg <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Check prefix: s[0:prefix_len-1] vs t[0:prefix_len-1]
                        if (i < prefix_len) begin
                            if (s_reg[i] != t_reg[i]) begin
                                result_reg <= 1'b0;
                                state <= FINISH;
                            end else begin
                                i <= i + 5'd1;
                            end
                        end else begin
                            state <= CHECK_SUFFIX;
                            i <= 5'd0;
                        end
                    end
                end

                CHECK_SUFFIX: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Check suffix: s[w+1:s_len] vs t[t_len-suffix_len:t_len]
                    // s index: wild_pos + 1 + i
                    // t index: t_len_reg - suffix_len + i
                    if (i < suffix_len) begin
                        if (s_reg[wild_pos + 1 + i] != t_reg[t_len_reg - suffix_len + i]) begin
                            result_reg <= 1'b0;
                            state <= FINISH;
                        end else begin
                            i <= i + 5'd1;
                        end
                    end else begin
                        result_reg <= 1'b1;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= result_reg;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Timeout protection
            if (cycle_counter >= MAX_CYCLES && state != FINISH && state != IDLE) begin
                state <= FINISH;
                result_reg <= 1'b0;
            end
        end
    end
endmodule