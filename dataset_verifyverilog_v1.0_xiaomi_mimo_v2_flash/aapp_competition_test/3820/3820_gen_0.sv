module string_match #(
    parameter MAX_LEN = 16,
    parameter DATA_WIDTH = 8
) (
    input clk,
    input rst_n,
    input start,
    input [7:0] s_arr [0:15],
    input [7:0] t_arr [0:15],
    input [4:0] n,
    input [4:0] m,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FIND_STAR = 3'd1;
    localparam [2:0] CHECK_LENGTH = 3'd2;
    localparam [2:0] COMPARE_PREFIX = 3'd3;
    localparam [2:0] COMPARE_SUFFIX = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] idx;
    reg [4:0] star_pos;
    reg star_found;
    reg [7:0] prefix_len;
    reg [7:0] suffix_len;
    reg prefix_match;
    reg suffix_match;
    reg length_ok;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = FIND_STAR;
                else
                    next_state = IDLE;
            end
            
            FIND_STAR: begin
                if (idx >= n || star_found)
                    next_state = CHECK_LENGTH;
                else
                    next_state = FIND_STAR;
            end
            
            CHECK_LENGTH: begin
                if (star_found) begin
                    if (length_ok)
                        next_state = COMPARE_PREFIX;
                    else
                        next_state = DONE_STATE;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            COMPARE_PREFIX: begin
                if (prefix_match && idx >= star_pos)
                    next_state = COMPARE_SUFFIX;
                else if (!prefix_match)
                    next_state = DONE_STATE;
                else
                    next_state = COMPARE_PREFIX;
            end
            
            COMPARE_SUFFIX: begin
                if (suffix_match && idx >= prefix_len)
                    next_state = DONE_STATE;
                else if (!suffix_match)
                    next_state = DONE_STATE;
                else
                    next_state = COMPARE_SUFFIX;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output and register logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            idx <= 5'd0;
            star_pos <= 5'd0;
            star_found <= 1'b0;
            prefix_len <= 8'd0;
            suffix_len <= 8'd0;
            prefix_match <= 1'b0;
            suffix_match <= 1'b0;
            length_ok <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        idx <= 5'd0;
                        star_pos <= 5'd0;
                        star_found <= 1'b0;
                    end
                end
                
                FIND_STAR: begin
                    if (idx < n && !star_found) begin
                        if (s_arr[idx] == 8'd42) begin
                            star_found <= 1'b1;
                            star_pos <= idx;
                        end
                        idx <= idx + 5'd1;
                    end
                end
                
                CHECK_LENGTH: begin
                    if (star_found) begin
                        // prefix_len = star_pos, suffix_len = n - star_pos - 1
                        prefix_len <= {3'd0, star_pos};
                        suffix_len <= {3'd0, n - star_pos - 5'd1};
                        length_ok <= ((n - 5'd1) <= m);
                    end
                    idx <= 5'd0;
                end
                
                COMPARE_PREFIX: begin
                    if (idx < star_pos) begin
                        if (s_arr[idx] != t_arr[idx]) begin
                            prefix_match <= 1'b0;
                        end else if (idx == star_pos - 5'd1) begin
                            prefix_match <= 1'b1;
                        end
                        idx <= idx + 5'd1;
                    end
                end
                
                COMPARE_SUFFIX: begin
                    if (idx < prefix_len) begin
                        // suffix starts at n - suffix_len in s
                        // suffix starts at m - suffix_len in t
                        if (s_arr[idx + star_pos + 5'd1] != t_arr[m - suffix_len + idx]) begin
                            suffix_match <= 1'b0;
                        end else if (idx == prefix_len - 8'd1) begin
                            suffix_match <= 1'b1;
                        end
                        idx <= idx + 5'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (star_found) begin
                        result <= prefix_match && suffix_match && length_ok;
                    end else begin
                        // No star: n must equal m and all chars match
                        if (n == m) begin
                            // Check all characters match
                            result <= (idx == n);
                        end else begin
                            result <= 1'b0;
                        end
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            state <= next_state;
        end
    end

endmodule