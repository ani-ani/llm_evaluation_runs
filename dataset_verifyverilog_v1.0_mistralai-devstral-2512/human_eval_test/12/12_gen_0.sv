module LongestStringFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] strings [0:7][0:15],
    input wire [3:0] num_strings,
    output reg done,
    output reg [2:0] longest_idx,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SCAN    = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    reg [1:0] state, next_state;
    reg [2:0] current_idx;
    reg [3:0] current_len;
    reg [3:0] max_len;
    reg [2:0] max_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Length counter for current string
    reg [3:0] char_count;
    reg [3:0] string_pos;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_idx <= 3'd0;
            current_len <= 4'd0;
            max_len <= 4'd0;
            max_idx <= 3'd0;
            cycle_count <= 8'd0;
            char_count <= 4'd0;
            string_pos <= 4'd0;
            done <= 1'b0;
            longest_idx <= 3'd0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_idx <= 3'd0;
                        max_len <= 4'd0;
                        max_idx <= 3'd0;
                        next_state <= SCAN;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN: begin
                    // Count non-null characters in current string
                    if (strings[current_idx][string_pos] != 8'd0) begin
                        char_count <= char_count + 4'd1;
                    end
                    string_pos <= string_pos + 4'd1;

                    if (string_pos == 4'd16 || strings[current_idx][string_pos-1] == 8'd0) begin
                        current_len <= char_count;
                        string_pos <= 4'd0;
                        char_count <= 4'd0;
                        next_state <= COMPARE;
                    end else begin
                        next_state <= SCAN;
                    end
                end

                COMPARE: begin
                    // Compare current length with max
                    if (current_len > max_len) begin
                        max_len <= current_len;
                        max_idx <= current_idx;
                    end

                    // Move to next string or finish
                    if (current_idx == (num_strings - 1)) begin
                        next_state <= DONE;
                    end else begin
                        current_idx <= current_idx + 3'd1;
                        next_state <= SCAN;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    longest_idx <= max_idx;
                    valid <= |num_strings;  // OR reduction
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule