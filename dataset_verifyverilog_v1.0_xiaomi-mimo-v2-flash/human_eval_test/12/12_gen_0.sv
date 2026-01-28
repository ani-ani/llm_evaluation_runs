module find_longest_string (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] strings [0:7][0:15],
    input wire [3:0] num_strings,
    output reg done,
    output reg [2:0] longest_idx,
    output reg valid
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [2:0] current_idx;
    reg [3:0] char_idx;
    reg [7:0] current_len;
    reg [7:0] max_len;
    reg [2:0] max_idx_reg;
    reg valid_reg;
    reg [7:0] scan_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            longest_idx <= 3'd0;
            valid <= 1'b0;
            current_idx <= 3'd0;
            char_idx <= 4'd0;
            current_len <= 8'd0;
            max_len <= 8'd0;
            max_idx_reg <= 3'd0;
            valid_reg <= 1'b0;
            scan_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    char_idx <= 4'd0;
                    current_len <= 8'd0;
                    max_len <= 8'd0;
                    max_idx_reg <= 3'd0;
                    valid_reg <= (|num_strings);
                    current_idx <= 3'd0;
                    scan_count <= 8'd0;
                    if (start && (num_strings > 4'd0)) begin
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    if (scan_count < 8'd128) begin
                        // Count non-null bytes in current string
                        if (strings[current_idx][char_idx] != 8'h00) begin
                            current_len <= current_len + 8'd1;
                        end
                        // Increment char index
                        if (char_idx < 4'd15) begin
                            char_idx <= char_idx + 4'd1;
                        end else begin
                            // Move to next string
                            char_idx <= 4'd0;
                            current_len <= 8'd0;
                            if (current_idx < 3'd7) begin
                                current_idx <= current_idx + 3'd1;
                                // Check if we've processed all valid strings
                                if (current_idx >= num_strings - 3'd1) begin
                                    current_idx <= 3'd0;
                                    char_idx <= 4'd0;
                                    state <= COMPARE;
                                end
                            end else begin
                                current_idx <= 3'd0;
                                char_idx <= 4'd0;
                                state <= COMPARE;
                            end
                        end
                        scan_count <= scan_count + 8'd1;
                    end else begin
                        // Timeout safety
                        state <= FINISH;
                    end
                end

                COMPARE: begin
                    // Compare current_len with max_len
                    // For first string (idx=0), just set max
                    if (current_idx == 3'd0) begin
                        max_len <= current_len;
                        max_idx_reg <= 3'd0;
                    end else if (current_idx < num_strings) begin
                        if (current_len > max_len) begin
                            max_len <= current_len;
                            max_idx_reg <= current_idx;
                        end
                        // If equal, do nothing (keeps first index)
                    end

                    // Move to next string or finish
                    if (current_idx < num_strings - 3'd1) begin
                        current_idx <= current_idx + 3'd1;
                        current_len <= 8'd0;
                        char_idx <= 4'd0;
                        // Read current string length in next cycle
                        state <= SCAN;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    longest_idx <= max_idx_reg;
                    valid <= valid_reg;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule