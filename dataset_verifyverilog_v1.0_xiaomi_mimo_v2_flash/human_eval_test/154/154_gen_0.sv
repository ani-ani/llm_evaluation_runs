module cycpattern_check(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [63:0] a,
    input [63:0] b,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ROTATIONS = 3'd1;
    localparam [2:0] GET_ROTATED_B = 3'd2;
    localparam [2:0] SEARCH_A = 3'd3;
    localparam [2:0] COMPARE_CHARS = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] rotation_idx;      // Current rotation (0 to len-1)
    reg [3:0] a_start_idx;       // Starting position in A for substring search
    reg [3:0] char_idx;          // Current character index in comparison
    reg [7:0] rotated_b_char;    // Current character from rotated B
    reg [7:0] a_char;            // Current character from A
    reg match_found;             // Flag if any match found
    reg [7:0] temp_b_char;       // Temporary storage for rotated B character
    reg [7:0] temp_a_char;       // Temporary storage for A character

    // Helper function to extract character from 64-bit packed string
    function automatic [7:0] get_char;
        input [63:0] str;
        input [3:0] idx;
        begin
            // str is packed as {char7, char6, ..., char0}
            // char_idx 0 is bits [7:0], 1 is [15:8], etc.
            get_char = str[8*idx +: 8];
        end
    endfunction

    // Helper function to generate rotated B character
    function automatic [7:0] get_rotated_char;
        input [63:0] str;
        input [3:0] len;
        input [3:0] rot_idx;
        input [3:0] char_idx;
        begin
            // For rotation rot_idx, character at position char_idx comes from
            // original position (char_idx + rot_idx) % len
            reg [3:0] orig_idx;
            orig_idx = (char_idx + rot_idx) % len;
            get_rotated_char = get_char(str, orig_idx);
        end
    endfunction

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            rotation_idx <= 4'd0;
            a_start_idx <= 4'd0;
            char_idx <= 4'd0;
            match_found <= 1'b0;
            rotated_b_char <= 8'd0;
            a_char <= 8'd0;
            temp_b_char <= 8'd0;
            temp_a_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        result <= 1'b0;
                        match_found <= 1'b0;
                        rotation_idx <= 4'd0;
                        a_start_idx <= 4'd0;
                        state <= CHECK_ROTATIONS;
                    end
                end

                CHECK_ROTATIONS: begin
                    // Check if we've tried all rotations
                    if (rotation_idx >= len) begin
                        state <= DONE;
                    end else begin
                        // Start checking this rotation against A
                        a_start_idx <= 4'd0;
                        state <= GET_ROTATED_B;
                    end
                end

                GET_ROTATED_B: begin
                    // Generate first character of rotated B for this rotation
                    // For rotation_idx, character at position 0 comes from original position rotation_idx
                    if (len == 4'd0) begin
                        // Edge case: empty string (shouldn't happen per spec)
                        state <= DONE;
                    end else begin
                        temp_b_char = get_rotated_char(b, len, rotation_idx, 4'd0);
                        rotated_b_char <= temp_b_char;
                        char_idx <= 4'd0;
                        state <= SEARCH_A;
                    end
                end

                SEARCH_A: begin
                    // Check if A_start_idx + len exceeds A's bounds
                    if (a_start_idx + len > 4'd8) begin
                        // No more positions in A to check for this rotation
                        rotation_idx <= rotation_idx + 4'd1;
                        state <= CHECK_ROTATIONS;
                    end else begin
                        // Compare rotated B against A starting at a_start_idx
                        char_idx <= 4'd0;
                        state <= COMPARE_CHARS;
                    end
                end

                COMPARE_CHARS: begin
                    // Compare current character
                    if (char_idx >= len) begin
                        // All characters matched for this rotation and position
                        match_found <= 1'b1;
                        state <= DONE;
                    end else begin
                        // Get character from rotated B at current index
                        temp_b_char = get_rotated_char(b, len, rotation_idx, char_idx);
                        rotated_b_char <= temp_b_char;
                        
                        // Get character from A at position (a_start_idx + char_idx)
                        temp_a_char = get_char(a, a_start_idx + char_idx);
                        a_char <= temp_a_char;
                        
                        if (temp_b_char == temp_a_char) begin
                            // Match, check next character
                            char_idx <= char_idx + 4'd1;
                            state <= COMPARE_CHARS;
                        end else begin
                            // Mismatch, try next position in A
                            a_start_idx <= a_start_idx + 4'd1;
                            state <= SEARCH_A;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (match_found) begin
                        result <= 1'b1;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule