module almost_palindrome_counter (
    input clk,
    input rst_n,
    input start,
    input [4:0] length_in,
    input [127:0] char_flat,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COUNTING
    } state_t;
    state_t state;

    // Internal registers for counting
    reg [3:0] i_reg;  // Start index
    reg [3:0] j_reg;  // End index
    reg [3:0] k_reg;  // Comparison index
    reg [3:0] mismatch_count;
    reg [3:0] mismatch_pos1, mismatch_pos2;
    reg [7:0] char1, char2;
    reg is_palindrome;
    reg is_almost_palindrome;

    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            i_reg <= 0;
            j_reg <= 0;
            k_reg <= 0;
            mismatch_count <= 0;
            mismatch_pos1 <= 0;
            mismatch_pos2 <= 0;
            is_palindrome <= 0;
            is_almost_palindrome <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COUNTING;
                        result <= 0;
                        done <= 0;
                        i_reg <= 0;
                        j_reg <= 0;
                        k_reg <= 0;
                        mismatch_count <= 0;
                        mismatch_pos1 <= 0;
                        mismatch_pos2 <= 0;
                        is_palindrome <= 0;
                        is_almost_palindrome <= 0;
                    end
                end
                COUNTING: begin
                    // Extract characters for comparison
                    char1 = char_flat[(i_reg + k_reg) * 8 +: 8];
                    char2 = char_flat[(j_reg - k_reg) * 8 +: 8];

                    // Check for palindrome
                    if (char1 != char2) begin
                        mismatch_count <= mismatch_count + 1;
                        if (mismatch_count == 1) begin
                            mismatch_pos1 <= i_reg + k_reg;
                        end else if (mismatch_count == 2) begin
                            mismatch_pos2 <= i_reg + k_reg;
                        end
                    end

                    // Move to next comparison
                    if (k_reg < (j_reg - i_reg) / 2) begin
                        k_reg <= k_reg + 1;
                    end else begin
                        // Check if palindrome or almost palindrome
                        if (mismatch_count == 0) begin
                            is_palindrome <= 1;
                            is_almost_palindrome <= 0;
                        end else if (mismatch_count == 2) begin
                            // Check if swapping the mismatched characters makes it a palindrome
                            reg [7:0] temp_char1, temp_char2, temp_char3, temp_char4;
                            temp_char1 = char_flat[mismatch_pos1 * 8 +: 8];
                            temp_char2 = char_flat[(j_reg - (mismatch_pos1 - i_reg)) * 8 +: 8];
                            temp_char3 = char_flat[mismatch_pos2 * 8 +: 8];
                            temp_char4 = char_flat[(j_reg - (mismatch_pos2 - i_reg)) * 8 +: 8];
                            if (temp_char1 == temp_char4 && temp_char3 == temp_char2) begin
                                is_almost_palindrome <= 1;
                            end else begin
                                is_almost_palindrome <= 0;
                            end
                            is_palindrome <= 0;
                        end else begin
                            is_palindrome <= 0;
                            is_almost_palindrome <= 0;
                        end

                        // Update result if valid
                        if (is_palindrome || is_almost_palindrome) begin
                            result <= result + 1;
                        end

                        // Reset for next substring
                        k_reg <= 0;
                        mismatch_count <= 0;
                        mismatch_pos1 <= 0;
                        mismatch_pos2 <= 0;
                        is_palindrome <= 0;
                        is_almost_palindrome <= 0;

                        // Move to next substring
                        if (j_reg < length_in - 1) begin
                            j_reg <= j_reg + 1;
                        end else begin
                            j_reg <= i_reg;
                            if (i_reg < length_in - 1) begin
                                i_reg <= i_reg + 1;
                            end else begin
                                state <= IDLE;
                                done <= 1;
                            end
                        end
                    end
                end
            endcase
        end
    end

endmodule