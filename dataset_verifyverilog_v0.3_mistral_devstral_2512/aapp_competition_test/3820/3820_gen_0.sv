module string_match #(
    parameter MAX_LEN = 16,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] s_arr [0:MAX_LEN-1],
    input wire [DATA_WIDTH-1:0] t_arr [0:MAX_LEN-1],
    input wire [4:0] n,
    input wire [4:0] m,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FIND_STAR = 3'd1;
    localparam [2:0] COMPARE_PREFIX = 3'd2;
    localparam [2:0] COMPARE_SUFFIX = 3'd3;
    localparam [2:0] CHECK_LENGTH = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] star_pos;
    reg [3:0] prefix_idx;
    reg [3:0] suffix_idx;
    reg [3:0] cycle_count;
    reg star_found;
    reg prefix_match;
    reg suffix_match;
    reg length_ok;
    localparam [7:0] MAX_CYCLES = 8'd100;
    localparam [7:0] WILDCARD = 8'd42;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            star_pos <= 4'd0;
            prefix_idx <= 4'd0;
            suffix_idx <= 4'd0;
            cycle_count <= 8'd0;
            star_found <= 1'b0;
            prefix_match <= 1'b1;
            suffix_match <= 1'b1;
            length_ok <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FIND_STAR;
                end
            end

            FIND_STAR: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else if (star_pos < n) begin
                    if (s_arr[star_pos] == WILDCARD) begin
                        star_found = 1'b1;
                        next_state = CHECK_LENGTH;
                    end else begin
                        star_pos <= star_pos + 4'd1;
                    end
                end else begin
                    star_found = 1'b0;
                    next_state = CHECK_LENGTH;
                end
            end

            CHECK_LENGTH: begin
                if (star_found) begin
                    length_ok = (n - 4'd1) <= m;
                    if (length_ok) begin
                        next_state = COMPARE_PREFIX;
                    end else begin
                        next_state = DONE_STATE;
                    end
                end else begin
                    length_ok = (n == m);
                    if (length_ok) begin
                        next_state = COMPARE_PREFIX;
                    end else begin
                        next_state = DONE_STATE;
                    end
                end
            end

            COMPARE_PREFIX: begin
                if (prefix_idx < (star_found ? star_pos : n)) begin
                    if (s_arr[prefix_idx] != t_arr[prefix_idx]) begin
                        prefix_match = 1'b0;
                        next_state = DONE_STATE;
                    end else begin
                        prefix_idx <= prefix_idx + 4'd1;
                    end
                end else begin
                    next_state = COMPARE_SUFFIX;
                end
            end

            COMPARE_SUFFIX: begin
                if (star_found) begin
                    if (suffix_idx < (n - star_pos - 4'd1)) begin
                        if (s_arr[star_pos + 4'd1 + suffix_idx] != t_arr[m - (n - star_pos - 4'd1) + suffix_idx]) begin
                            suffix_match = 1'b0;
                            next_state = DONE_STATE;
                        end else begin
                            suffix_idx <= suffix_idx + 4'd1;
                        end
                    end else begin
                        next_state = DONE_STATE;
                    end
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        result = 1'b0;
        done = 1'b0;
        case (state)
            DONE_STATE: begin
                if (star_found) begin
                    result = prefix_match && suffix_match && length_ok;
                end else begin
                    result = prefix_match && length_ok;
                end
                done = 1'b1;
            end
            default: begin
                result = 1'b0;
                done = 1'b0;
            end
        endcase
    end

    // Cycle counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                cycle_count <= 8'd0;
            end
        end
    end

endmodule