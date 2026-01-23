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

    reg [1:0] state, next_state;
    reg [3:0] idx_s;           // Index for s array
    reg [3:0] idx_c;           // Index for c array
    reg [3:0] idx_result;      // Index for result array
    reg [3:0] check_idx;       // Index for palindrome check
    reg match_found;           // Flag for character match
    reg [3:0] temp_result_len; // Temporary result length
    reg temp_palindrome;       // Temporary palindrome flag

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            palindrome <= 1'b0;
            idx_s <= 4'd0;
            idx_c <= 4'd0;
            idx_result <= 4'd0;
            check_idx <= 4'd0;
            match_found <= 1'b0;
            temp_result_len <= 4'd0;
            temp_palindrome <= 1'b1;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = DELETE;
                    done = 1'b0;
                    result_len = 4'd0;
                    palindrome = 1'b0;
                    idx_s = 4'd0;
                    idx_c = 4'd0;
                    idx_result = 4'd0;
                    check_idx = 4'd0;
                    match_found = 1'b0;
                    temp_result_len = 4'd0;
                    temp_palindrome = 1'b1;
                end
            end

            DELETE: begin
                if (idx_s < s_len) begin
                    // Check if current s character matches any in c
                    match_found = 1'b0;
                    for (idx_c = 0; idx_c < c_len; idx_c = idx_c + 1) begin
                        if (s[idx_s] == c[idx_c]) begin
                            match_found = 1'b1;
                        end
                    end

                    // If no match, add to result
                    if (!match_found) begin
                        result[idx_result] = s[idx_s];
                        idx_result = idx_result + 1;
                    end

                    idx_s = idx_s + 1;
                end else begin
                    // Done with deletion, move to check
                    temp_result_len = idx_result;
                    next_state = CHECK;
                    idx_s = 4'd0;
                    idx_c = 4'd0;
                    check_idx = 4'd0;
                end
            end

            CHECK: begin
                if (temp_result_len <= 1) begin
                    temp_palindrome = 1'b1;
                    next_state = DONE;
                end else if (check_idx < (temp_result_len / 2)) begin
                    if (result[check_idx] != result[temp_result_len - 1 - check_idx]) begin
                        temp_palindrome = 1'b0;
                    end
                    check_idx = check_idx + 1;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                result_len = temp_result_len;
                palindrome = temp_palindrome;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule