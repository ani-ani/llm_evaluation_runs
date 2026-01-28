module wildcard_match(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FIND_WILDCARD = 3'd1;
    localparam [2:0] CHECK_PREFIX = 3'd2;
    localparam [2:0] CHECK_SUFFIX = 3'd3;
    localparam [2:0] COMPARE_NO_WILDCARD = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers for s and t arrays
    reg [7:0] s [0:15];
    reg [7:0] t [0:15];
    reg [4:0] s_len_reg, t_len_reg;
    reg [3:0] wildcard_pos;
    reg [3:0] prefix_len, suffix_len;
    reg [3:0] i, j;
    reg wildcard_found;
    reg prefix_match, suffix_match;

    // Initialize arrays and registers
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            wildcard_pos <= 4'd0;
            prefix_len <= 4'd0;
            suffix_len <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            wildcard_found <= 1'b0;
            prefix_match <= 1'b1;
            suffix_match <= 1'b1;
            s_len_reg <= 5'd0;
            t_len_reg <= 5'd0;
            for (k = 0; k < 16; k = k + 1) begin
                s[k] <= 8'd0;
                t[k] <= 8'd0;
            end
        end else begin
            // Update state
            state <= next_state;

            // Update cycle count
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
            end

            // State machine
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load inputs
                        s[0] <= s_char_0;
                        s[1] <= s_char_1;
                        s[2] <= s_char_2;
                        s[3] <= s_char_3;
                        s[4] <= s_char_4;
                        s[5] <= s_char_5;
                        s[6] <= s_char_6;
                        s[7] <= s_char_7;
                        s[8] <= s_char_8;
                        s[9] <= s_char_9;
                        s[10] <= s_char_10;
                        s[11] <= s_char_11;
                        s[12] <= s_char_12;
                        s[13] <= s_char_13;
                        s[14] <= s_char_14;
                        s[15] <= s_char_15;
                        t[0] <= t_char_0;
                        t[1] <= t_char_1;
                        t[2] <= t_char_2;
                        t[3] <= t_char_3;
                        t[4] <= t_char_4;
                        t[5] <= t_char_5;
                        t[6] <= t_char_6;
                        t[7] <= t_char_7;
                        t[8] <= t_char_8;
                        t[9] <= t_char_9;
                        t[10] <= t_char_10;
                        t[11] <= t_char_11;
                        t[12] <= t_char_12;
                        t[13] <= t_char_13;
                        t[14] <= t_char_14;
                        t[15] <= t_char_15;
                        s_len_reg <= s_len;
                        t_len_reg <= t_len;
                        
                        // Initialize
                        wildcard_found <= 1'b0;
                        wildcard_pos <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        prefix_match <= 1'b1;
                        suffix_match <= 1'b1;
                        cycle_count <= 8'd0;
                        
                        next_state <= FIND_WILDCARD;
                    end
                end

                FIND_WILDCARD: begin
                    if (i < s_len_reg) begin
                        if (s[i] == 8'd42) begin  // '*' found
                            wildcard_found <= 1'b1;
                            wildcard_pos <= i;
                            prefix_len <= i;
                            suffix_len <= s_len_reg - i - 1;
                            i <= 4'd0;
                            next_state <= CHECK_PREFIX;
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        // No wildcard found
                        i <= 4'd0;
                        next_state <= COMPARE_NO_WILDCARD;
                    end
                end

                CHECK_PREFIX: begin
                    if (i < prefix_len) begin
                        if (s[i] != t[i]) begin
                            prefix_match <= 1'b0;
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        if (prefix_match) begin
                            next_state <= CHECK_SUFFIX;
                        end else begin
                            next_state <= FINISH;
                        end
                    end
                end

                CHECK_SUFFIX: begin
                    if (i < suffix_len) begin
                        if (s[wildcard_pos + 1 + i] != t[t_len_reg - suffix_len + i]) begin
                            suffix_match <= 1'b0;
                        end
                        i <= i + 4'd1;
                    end else begin
                        if (prefix_match && suffix_match && (prefix_len + suffix_len <= t_len_reg)) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                        next_state <= FINISH;
                    end
                end

                COMPARE_NO_WILDCARD: begin
                    if (i < s_len_reg) begin
                        if (s[i] != t[i]) begin
                            result <= 1'b0;
                        end
                        i <= i + 4'd1;
                    end else begin
                        if (s_len_reg == t_len_reg) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end
endmodule