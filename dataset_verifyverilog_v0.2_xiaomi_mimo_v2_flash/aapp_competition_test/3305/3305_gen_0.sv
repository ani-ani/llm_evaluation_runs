module almost_palindrome_counter (
    input clk,
    input rst_n,
    input start,
    input [4:0] length_in,
    input [127:0] char_flat,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CALC_I = 3'b001;
    localparam CALC_J = 3'b010;
    localparam CHECK_PAL = 3'b011;
    localparam CHECK_MISMATCH = 3'b100;
    localparam CHECK_SWAP = 3'b101;
    localparam UPDATE_COUNT = 3'b110;

    reg [2:0] state;
    reg [4:0] i;
    reg [4:0] j;
    reg [4:0] k;
    reg [4:0] mid;
    reg [4:0] length_reg;
    
    // Mismatch tracking
    reg [3:0] mismatch_count;
    reg [4:0] p_idx; // index of first char in mismatch pair
    reg [4:0] q_idx; // index of second char in mismatch pair
    reg [4:0] r_idx; // index of first char in second mismatch pair
    reg [4:0] s_idx; // index of second char in second mismatch pair

    // Helper to get char at index (0-based)
    wire [7:0] char_at [15:0];
    genvar g;
    generate
        for (g = 0; g < 16; g = g + 1) begin : char_gen
            assign char_at[g] = char_flat[g*8 +: 8];
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'b0;
            done <= 1'b0;
            i <= 5'b0;
            j <= 5'b0;
            k <= 5'b0;
            mismatch_count <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC_I;
                        result <= 16'b0;
                        i <= 5'b0;
                        length_reg <= length_in;
                    end
                end

                CALC_I: begin
                    if (i < length_reg) begin
                        state <= CALC_J;
                        j <= i;
                    end else begin
                        state <= IDLE;
                        done <= 1'b1;
                    end
                end

                CALC_J: begin
                    if (j < length_reg) begin
                        state <= CHECK_PAL;
                        k <= 5'b0;
                        mismatch_count <= 4'b0;
                        mid <= (j - i) >> 1; // length = j-i+1, so mid offset is (len-1)/2 = (j-i)/2
                    end else begin
                        state <= CALC_I;
                        i <= i + 1'b1;
                    end
                end

                CHECK_PAL: begin
                    // Loop to check palindrome and count mismatches
                    // k goes from 0 to mid
                    if (k <= mid) begin
                        if (char_at[i + k] != char_at[j - k]) begin
                            // Mismatch found
                            if (mismatch_count == 0) begin
                                p_idx <= i + k;
                                q_idx <= j - k;
                                mismatch_count <= 1;
                            end else if (mismatch_count == 1) begin
                                r_idx <= i + k;
                                s_idx <= j - k;
                                mismatch_count <= 2;
                            end else begin
                                mismatch_count <= 3; // More than 2 mismatches
                            end
                        end
                        k <= k + 1'b1;
                    end else begin
                        // Finished checking substring
                        if (mismatch_count == 0) begin
                            // It's a palindrome
                            state <= UPDATE_COUNT;
                        end else if (mismatch_count == 1) begin
                            // 1 mismatch -> cannot be fixed by swapping 2 characters
                            state <= UPDATE_COUNT; // Skip incrementing result
                        end else if (mismatch_count == 2) begin
                            state <= CHECK_SWAP;
                        end else begin
                            // > 2 mismatches
                            state <= UPDATE_COUNT; // Skip incrementing result
                        end
                    end
                end

                CHECK_SWAP: begin
                    // Check if swapping makes it a palindrome
                    // We need char[p_idx] == char[s_idx] AND char[r_idx] == char[q_idx]
                    // Note: p_idx and r_idx are indices on the left side, q_idx and s_idx on the right side relative to the substring logic
                    // But the logic derived in thought process: mismatch at (p, q) and (r, s).
                    // We need char[p] == char[s] and char[r] == char[q].
                    if ((char_at[p_idx] == char_at[s_idx]) && (char_at[r_idx] == char_at[q_idx])) begin
                        state <= UPDATE_COUNT;
                    end else begin
                        state <= UPDATE_COUNT; // Not fixable, do not increment
                    end
                end

                UPDATE_COUNT: begin
                    // If we are here, either it was a palindrome (mismatch_count=0) 
                    // OR it was 2 mismatches and fixable (mismatch_count=2, passed check)
                    // OR it was 1 or >2 mismatches (which came here directly to skip)
                    // We only increment if valid.
                    if (mismatch_count == 0 || mismatch_count == 2) begin
                        result <= result + 1'b1;
                    end
                    state <= CALC_J;
                    j <= j + 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
