module square_killer_finder (
    input clk,
    input rst_n,
    input start,
    input [15:0] matrix_row [15:0],
    output reg [4:0] max_size,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_SIZE = 3'b001;
    localparam CHECK_POSITION = 3'b010;
    localparam CHECK_SYMMETRY = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [4:0] s_reg, next_s_reg; // Current size being checked (16 to 2)
    reg [3:0] i_reg, next_i_reg; // Current top-left row
    reg [3:0] j_reg, next_j_reg; // Current top-left col
    reg [4:0] max_size_reg, next_max_size_reg;
    reg done_reg, next_done_reg;

    // Symmetry check variables
    reg [3:0] r_cnt, next_r_cnt;
    reg [3:0] c_cnt, next_c_cnt;
    reg is_symmetric, next_is_symmetric;

    // Helper wires for indices
    wire [3:0] curr_row_1, curr_row_2;
    wire [3:0] curr_col_1, curr_col_2;
    wire [3:0] s_minus_1;
    wire [3:0] s_minus_1_minus_r;
    wire [3:0] s_minus_1_minus_c;

    assign s_minus_1 = s_reg[3:0] - 1'b1;
    assign s_minus_1_minus_r = s_minus_1 - r_cnt;
    assign s_minus_1_minus_c = s_minus_1 - c_cnt;

    // Calculate absolute coordinates within the matrix
    assign curr_row_1 = i_reg + r_cnt;
    assign curr_col_1 = j_reg + c_cnt;
    assign curr_row_2 = i_reg + s_minus_1_minus_r;
    assign curr_col_2 = j_reg + s_minus_1_minus_c;

    // Matrix access
    // matrix_row is arranged as [row][col]
    // Input is [15:0] matrix_row [15:0], so matrix_row[x] gives row x
    wire val1, val2;
    assign val1 = matrix_row[curr_row_1][curr_col_1];
    assign val2 = matrix_row[curr_row_2][curr_col_2];

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            s_reg <= 0;
            i_reg <= 0;
            j_reg <= 0;
            max_size_reg <= 0;
            done_reg <= 0;
            r_cnt <= 0;
            c_cnt <= 0;
            is_symmetric <= 0;
        end else begin
            state <= next_state;
            s_reg <= next_s_reg;
            i_reg <= next_i_reg;
            j_reg <= next_j_reg;
            max_size_reg <= next_max_size_reg;
            done_reg <= next_done_reg;
            r_cnt <= next_r_cnt;
            c_cnt <= next_c_cnt;
            is_symmetric <= next_is_symmetric;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_s_reg = s_reg;
        next_i_reg = i_reg;
        next_j_reg = j_reg;
        next_max_size_reg = max_size_reg;
        next_done_reg = done_reg;
        next_r_cnt = r_cnt;
        next_c_cnt = c_cnt;
        next_is_symmetric = is_symmetric;

        case (state)
            IDLE: begin
                next_done_reg = 0;
                next_max_size_reg = 0;
                if (start) begin
                    next_state = CHECK_SIZE;
                    next_s_reg = 16; // Start from largest size
                    next_i_reg = 0;
                    next_j_reg = 0;
                end
            end

            CHECK_SIZE: begin
                // If size < 2, we are done (no killer found)
                if (s_reg < 2) begin
                    next_state = DONE;
                end else begin
                    // Check if current size fits in matrix
                    // 16x16 matrix. Max valid top-left for size s is 16-s.
                    // Since indices are 0-15, max index is 16-s-1 = 15-s.
                    // But logic starts at 0,0.
                    next_i_reg = 0;
                    next_j_reg = 0;
                    next_state = CHECK_POSITION;
                end
            end

            CHECK_POSITION: begin
                // Check if current (i, j) is valid for size s_reg
                // Valid if i + s <= 16 and j + s <= 16
                // i_reg and j_reg are 4 bits (0-15)
                if (i_reg + s_reg[3:0] > 16 || j_reg + s_reg[3:0] > 16) begin
                    // End of row/positions for current size
                    // Try next size
                    next_s_reg = s_reg - 1;
                    next_state = CHECK_SIZE;
                end else begin
                    // Valid position, start symmetry check
                    next_r_cnt = 0;
                    next_c_cnt = 0;
                    next_is_symmetric = 1; // Assume symmetric until proven otherwise
                    next_state = CHECK_SYMMETRY;
                end
            end

            CHECK_SYMMETRY: begin
                // Check pair (r, c) vs (s-1-r, s-1-c)
                // Optimization: We only need to check half of the elements.
                // Condition: r <= s-1-r (or r < s/2). If r > s-1-r, we already covered.
                // Also c <= s-1-c.
                // However, simpler: iterate r from 0 to s-1, c from 0 to s-1.
                // Break if we find mismatch.
                // To avoid checking twice, stop when 2*r >= s or 2*c >= s.

                // Check mismatch
                if (val1 != val2) begin
                    next_is_symmetric = 0;
                    // Optimization: Jump to next position immediately
                    // Increment j
                    if (j_reg + s_reg[3:0] < 16) begin
                        next_j_reg = j_reg + 1;
                        next_state = CHECK_POSITION;
                    end else begin
                        // Wrap to next row
                        next_j_reg = 0;
                        if (i_reg + s_reg[3:0] < 16) begin
                            next_i_reg = i_reg + 1;
                            next_state = CHECK_POSITION;
                        end else begin
                            // Checked all positions for this size
                            next_s_reg = s_reg - 1;
                            next_state = CHECK_SIZE;
                        end
                    end
                end else begin
                    // Advance counters
                    if (c_cnt < s_reg[3:0] - 1) begin
                        next_c_cnt = c_cnt + 1;
                    end else begin
                        next_c_cnt = 0;
                        if (r_cnt < s_reg[3:0] - 1) begin
                            next_r_cnt = r_cnt + 1;
                        end else begin
                            // Completed all checks for this square without mismatch
                            // Found a square killer
                            next_max_size_reg = s_reg;
                            // Continue searching for potentially same size or smaller? 
                            // Problem says "largest square submatrix".
                            // Since we go 16 down to 2, finding one means it's the max for this size.
                            // But we must continue to find if a larger size exists (we are going down, so no).
                            // Actually, we start at 16 and go down. First found is the answer.
                            next_state = DONE;
                        end
                    end
                end

                // Safety break for size 1 check loop logic
                // Logic to check only half:
                // If 2*r >= s, we are done.
                // If 2*c >= s, we are done.
                // Update logic:
                if (2*r_cnt >= s_reg[3:0] || 2*c_cnt >= s_reg[3:0]) begin
                    // We finished checking all necessary pairs for this square
                    if (is_symmetric && val1 == val2) begin // Should be true if we didn't fail earlier logic, but explicit check
                        next_max_size_reg = s_reg;
                        next_state = DONE;
                    end else if (!is_symmetric) begin
                        // Should have jumped out earlier, but fail-safe
                        if (j_reg + s_reg[3:0] < 16) begin
                            next_j_reg = j_reg + 1;
                            next_state = CHECK_POSITION;
                        end else begin
                            next_j_reg = 0;
                            if (i_reg + s_reg[3:0] < 16) begin
                                next_i_reg = i_reg + 1;
                                next_state = CHECK_POSITION;
                            end else begin
                                next_s_reg = s_reg - 1;
                                next_state = CHECK_SIZE;
                            end
                        end
                    end
                end

                // Correction to the logic above: The previous block (val1 != val2) handled increment.
                // If we reach here, val1 == val2. We need to advance indices.
                // Re-structuring the CHECK_SYMMETRY block to be cleaner:

                // Resetting next_* to defaults first is safer inside the block.
                next_r_cnt = r_cnt;
                next_c_cnt = c_cnt;
                next_is_symmetric = is_symmetric;

                if (val1 != val2) begin
                    next_is_symmetric = 0;
                    // Move to next position
                    if (j_reg + s_reg[3:0] < 16) begin
                        next_j_reg = j_reg + 1;
                    end else begin
                        next_j_reg = 0;
                        if (i_reg + s_reg[3:0] < 16) begin
                            next_i_reg = i_reg + 1;
                        end else begin
                            next_s_reg = s_reg - 1;
                            next_state = CHECK_SIZE;
                            // Need to ensure we don't fall through to position update
                            // But default state is CHECK_SYMMETRY, so we must update next_state here explicitly if we want to change it.
                            // The logic below handles state transition.
                            // Let's use explicit jumps to avoid complexity.
                        end
                    end
                    // Determine next state based on position update
                    if (j_reg + s_reg[3:0] < 16) begin
                         next_state = CHECK_POSITION;
                    end else if (i_reg + s_reg[3:0] < 16) begin
                         next_state = CHECK_POSITION;
                    end else begin
                         next_state = CHECK_SIZE;
                    end

                end else begin
                    // Match. Advance counters.
                    // Only need to check until 2*r >= s-1 (or s) and 2*c >= s-1 (or s).
                    // Actually, indices go 0 to s-1. Pair is (r,c) and (s-1-r, s-1-c).
                    // If 2*r >= s, we are done with rows.
                    // If 2*c >= s, we are done with cols.

                    if (2*c_cnt < s_reg[3:0] - 1) begin
                        next_c_cnt = c_cnt + 1;
                    end else begin
                        next_c_cnt = 0;
                        if (2*r_cnt < s_reg[3:0] - 1) begin
                            next_r_cnt = r_cnt + 1;
                        end else begin
                            // Symmetry confirmed for this square
                            next_max_size_reg = s_reg;
                            next_state = DONE;
                        end
                    end
                end
            end

            DONE: begin
                next_done_reg = 1;
                if (!start) begin
                    // Wait for start to go low to reset? Or just stay done.
                    // Staying done is fine.
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_size <= 0;
            done <= 0;
        end else begin
            max_size <= max_size_reg;
            done <= done_reg;
        end
    end

endmodule

module TopWrapper(
    input clk,
    input rst_n,
    input start,
    input [15:0] matrix_row [15:0],
    output [4:0] max_size,
    output done
);
    square_killer_finder skf (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_row(matrix_row),
        .max_size(max_size),
        .done(done)
    );
endmodule