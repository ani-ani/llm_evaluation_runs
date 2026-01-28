module reverse_delete(
    input clk,
    input rst_n,
    input start,
    input [7:0] s [0:7],
    input [7:0] c [0:7],
    input [3:0] s_len,
    input [3:0] c_len,
    output reg [7:0] result [0:7],
    output reg [3:0] result_len,
    output reg palindrome,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] DELETE  = 2'd1;
    localparam [1:0] CHECK   = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] idx_s;          // Index for string s
    reg [3:0] idx_c;          // Index for string c
    reg [3:0] result_idx;     // Index for result array
    reg [2:0] check_idx;      // Index for palindrome check
    reg match_found;          // Flag for character match in deletion
    reg mismatch_found;       // Flag for palindrome mismatch

    // Internal wires
    wire [7:0] s_char;
    wire [7:0] c_char;
    wire [7:0] result_left;
    wire [7:0] result_right;

    // Assignments for array access (avoiding packed array issues)
    assign s_char = s[idx_s];
    assign c_char = c[idx_c];
    assign result_left = result[check_idx];
    assign result_right = result[result_len - 1 - check_idx];

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            idx_s <= 4'd0;
            idx_c <= 4'd0;
            result_idx <= 4'd0;
            result_len <= 4'd0;
            check_idx <= 3'd0;
            match_found <= 1'b0;
            mismatch_found <= 1'b0;
            palindrome <= 1'b0;
            done <= 1'b0;
            // Initialize result array to 0
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for deletion stage
                        idx_s <= 4'd0;
                        result_idx <= 4'd0;
                        result_len <= 4'd0;
                        idx_c <= 4'd0;
                        match_found <= 1'b0;
                        next_state <= DELETE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                DELETE: begin
                    // Process character s[idx_s]
                    if (idx_s < s_len) begin
                        // Check if s[idx_s] matches any char in c
                        if (idx_c < c_len) begin
                            if (c_char == s_char) begin
                                match_found <= 1'b1;
                            end
                            idx_c <= idx_c + 4'd1;
                            next_state <= DELETE;
                        end else begin
                            // Finished checking against all c characters
                            if (!match_found) begin
                                // No match found, add to result
                                result[result_idx] <= s_char;
                                result_idx <= result_idx + 4'd1;
                                result_len <= result_len + 4'd1;
                            end
                            // Reset for next s character
                            idx_s <= idx_s + 4'd1;
                            idx_c <= 4'd0;
                            match_found <= 1'b0;
                            next_state <= DELETE;
                        end
                    end else begin
                        // Finished processing all s characters
                        // Initialize for palindrome check
                        check_idx <= 3'd0;
                        mismatch_found <= 1'b0;
                        if (result_len <= 4'd1) begin
                            // 0 or 1 character is always palindrome
                            palindrome <= 1'b1;
                            next_state <= DONE;
                        end else begin
                            next_state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    // Check if result is palindrome
                    if (check_idx < (result_len >> 1)) begin
                        if (result_left != result_right) begin
                            mismatch_found <= 1'b1;
                        end
                        check_idx <= check_idx + 3'd1;
                        next_state <= CHECK;
                    end else begin
                        // Finished all checks
                        if (mismatch_found) begin
                            palindrome <= 1'b0;
                        end else begin
                            palindrome <= 1'b1;
                        end
                        next_state <= DONE;
                    end
                end

                DONE: begin
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