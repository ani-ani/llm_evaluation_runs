module CharacterDeletionPalindrome (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s_chars [0:15],
    input wire [7:0] c_chars [0:15],
    input wire [3:0] s_len,
    output reg [7:0] result_chars [0:15],
    output reg [3:0] result_len,
    output reg is_palindrome,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN_DELETE = 2'd1;
    localparam [1:0] CHECK_PALINDROME = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] s_idx, next_s_idx;        // Index in s_chars
    reg [3:0] c_idx, next_c_idx;        // Index in c_chars
    reg [3:0] res_idx, next_res_idx;    // Index in result_chars
    reg [3:0] pal_idx, next_pal_idx;    // Index for palindrome check
    reg [3:0] temp_len, next_temp_len;  // Temporary result_len
    reg match_found, next_match_found;  // Flag for character match
    reg pal_mismatch, next_pal_mismatch; // Flag for palindrome failure

    integer i;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_len <= 4'd0;
            is_palindrome <= 1'b0;
            done <= 1'b0;
            s_idx <= 4'd0;
            c_idx <= 4'd0;
            res_idx <= 4'd0;
            pal_idx <= 4'd0;
            temp_len <= 4'd0;
            match_found <= 1'b0;
            pal_mismatch <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                result_chars[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            s_idx <= next_s_idx;
            c_idx <= next_c_idx;
            res_idx <= next_res_idx;
            pal_idx <= next_pal_idx;
            temp_len <= next_temp_len;
            match_found <= next_match_found;
            pal_mismatch <= next_pal_mismatch;
            
            // Update outputs based on state
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        result_len <= 4'd0;
                        is_palindrome <= 1'b0;
                        // Initialize result_chars to zeros
                        for (i = 0; i < 16; i = i + 1) begin
                            result_chars[i] <= 8'd0;
                        end
                    end
                end
                SCAN_DELETE: begin
                    // Pass-through logic for temp_len to result_len in FINISHED
                    // result_len is only updated at FINISHED
                end
                CHECK_PALINDROME: begin
                    // Pass-through logic for pal_mismatch to is_palindrome in FINISHED
                end
                FINISHED: begin
                    result_len <= temp_len;
                    if (pal_mismatch) begin
                        is_palindrome <= 1'b0;
                    end else begin
                        is_palindrome <= 1'b1;
                    end
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        // Defaults
        next_state = state;
        next_s_idx = s_idx;
        next_c_idx = c_idx;
        next_res_idx = res_idx;
        next_pal_idx = pal_idx;
        next_temp_len = temp_len;
        next_match_found = match_found;
        next_pal_mismatch = pal_mismatch;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN_DELETE;
                    next_s_idx = 4'd0;
                    next_c_idx = 4'd0;
                    next_res_idx = 4'd0;
                    next_temp_len = 4'd0;
                    next_match_found = 1'b0;
                end
            end

            SCAN_DELETE: begin
                if (s_idx < s_len) begin
                    // Inner loop over c_chars
                    if (c_idx < 16) begin
                        // Check if character matches (if c_chars[c_idx] is not null terminator or 0)
                        if ((c_chars[c_idx] == s_chars[s_idx]) && (c_chars[c_idx] != 8'd0)) begin
                            next_match_found = 1'b1;
                        end
                        next_c_idx = c_idx + 4'd1;
                    end else begin
                        // Finished checking all c_chars for this s_char
                        if (!match_found) begin
                            // No match found, copy to result
                            next_res_idx = res_idx + 4'd1;
                            next_temp_len = temp_len + 4'd1;
                        end
                        // Move to next s_char
                        next_s_idx = s_idx + 4'd1;
                        next_c_idx = 4'd0;
                        next_match_found = 1'b0;
                    end
                end else begin
                    // Finished scanning s_chars
                    next_state = CHECK_PALINDROME;
                    next_pal_idx = 4'd0;
                    next_pal_mismatch = 1'b0;
                end
            end

            CHECK_PALINDROME: begin
                if (temp_len <= 4'd1) begin
                    // 0 or 1 character is always a palindrome
                    next_pal_mismatch = 1'b0;
                    next_state = FINISHED;
                end else if (pal_idx < (temp_len >> 1)) begin
                    // Compare char at pal_idx with char at (temp_len - 1 - pal_idx)
                    if (result_chars[pal_idx] != result_chars[temp_len - 1 - pal_idx]) begin
                        next_pal_mismatch = 1'b1;
                        next_state = FINISHED; // Fail fast
                    end else begin
                        next_pal_idx = pal_idx + 4'd1;
                    end
                end else begin
                    // Finished comparison loop
                    next_state = FINISHED;
                end
            end

            FINISHED: begin
                // Return to IDLE immediately after done pulse
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule