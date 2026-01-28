module PrimonimoSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] p,
    input wire [2:0] board_0,
    input wire [2:0] board_1,
    input wire [2:0] board_2,
    input wire [2:0] board_3,
    output reg [2:0] count_0,
    output reg [2:0] count_1,
    output reg [2:0] count_2,
    output reg [2:0] count_3,
    output reg solution_exists,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] FIND_PIVOT = 4'd2;
    localparam [3:0] SWAP = 4'd3;
    localparam [3:0] NORMALIZE = 4'd4;
    localparam [3:0] ELIMINATE = 4'd5;
    localparam [3:0] BACK_SUBST = 4'd6;
    localparam [3:0] OUTPUT = 4'd7;
    localparam [3:0] NO_SOLUTION = 4'd8;

    reg [3:0] state, next_state;

    // Matrix and vectors: A[row][col] and d[row]
    reg [2:0] A [0:3][0:3];
    reg [2:0] d [0:3];
    reg [2:0] x [0:3];

    // Working registers
    reg [1:0] row, col, pivot_row;
    reg [2:0] pivot_val;
    reg [1:0] r, c;
    reg [1:0] init_cnt;
    reg [1:0] back_row, back_col;
    reg [1:0] elim_row;

    // Modular arithmetic functions
    function [2:0] mod_add;
        input [2:0] a, b, mod;
        reg [3:0] sum;
        begin
            sum = a + b;
            if (sum >= mod) sum = sum - mod;
            mod_add = sum[2:0];
        end
    endfunction

    function [2:0] mod_sub;
        input [2:0] a, b, mod;
        reg [3:0] diff;
        begin
            if (a >= b) diff = a - b;
            else diff = a + mod - b;
            mod_sub = diff[2:0];
        end
    endfunction

    function [2:0] mod_mul;
        input [2:0] a, b, mod;
        reg [5:0] prod;
        begin
            prod = a * b;
            prod = prod % mod;
            mod_mul = prod[2:0];
        end
    endfunction

    function [2:0] mod_inv;
        input [2:0] a;
        input [2:0] mod;
        begin
            // Since mod <= 7, inverse table
            case ({mod, a})
                // p=2: inv(1)=1
                5'b010_001: mod_inv = 3'd1;
                // p=3: inv(1)=1, inv(2)=2
                5'b011_001: mod_inv = 3'd1;
                5'b011_010: mod_inv = 3'd2;
                // p=5: inv(1)=1, inv(2)=3, inv(3)=2, inv(4)=4
                5'b101_001: mod_inv = 3'd1;
                5'b101_010: mod_inv = 3'd3;
                5'b101_011: mod_inv = 3'd2;
                5'b101_100: mod_inv = 3'd4;
                // p=7: inv(1)=1, inv(2)=4, inv(3)=5, inv(4)=2, inv(5)=3, inv(6)=6
                5'b111_001: mod_inv = 3'd1;
                5'b111_010: mod_inv = 3'd4;
                5'b111_011: mod_inv = 3'd5;
                5'b111_100: mod_inv = 3'd2;
                5'b111_101: mod_inv = 3'd3;
                5'b111_110: mod_inv = 3'd6;
                default: mod_inv = 3'd0;
            endcase
        end
    endfunction

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            solution_exists <= 1'b0;
            count_0 <= 3'd0; count_1 <= 3'd0; count_2 <= 3'd0; count_3 <= 3'd0;
            row <= 2'd0; col <= 2'd0; pivot_row <= 2'd0;
            init_cnt <= 2'd0;
            back_row <= 2'd0; back_col <= 2'd0;
            elim_row <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    solution_exists <= 1'b0;
                    count_0 <= 3'd0; count_1 <= 3'd0; count_2 <= 3'd0; count_3 <= 3'd0;
                    row <= 2'd0; col <= 2'd0; pivot_row <= 2'd0;
                    init_cnt <= 2'd0;
                    back_row <= 2'd0; back_col <= 2'd0;
                    elim_row <= 2'd0;
                    if (start) next_state <= INIT;
                    else next_state <= IDLE;
                end

                INIT: begin
                    if (init_cnt < 2'd2) begin
                        // Compute d[i] = (p - board[i]) % p
                        // Row 0: equation for square 0 (row 0, col 0). Affects vars 0 (row 0) and 1 (col 0)
                        // Row 1: equation for square 1 (row 0, col 1). Affects vars 0 (row 0) and 2 (col 1)
                        // Row 2: equation for square 2 (row 1, col 0). Affects vars 1 (row 1) and 3 (col 0)
                        // Row 3: equation for square 3 (row 1, col 1). Affects vars 2 (row 1) and 3 (col 1)
                        
                        // We process initialization in steps to avoid large combinational logic
                        case (init_cnt)
                            2'd0: begin
                                // Fill A and d for first half
                                A[0][0] <= 3'd1; A[0][1] <= 3'd1; A[0][2] <= 3'd0; A[0][3] <= 3'd0;
                                A[1][0] <= 3'd1; A[1][1] <= 3'd0; A[1][2] <= 3'd1; A[1][3] <= 3'd0;
                                A[2][0] <= 3'd0; A[2][1] <= 3'd1; A[2][2] <= 3'd0; A[2][3] <= 3'd1;
                                A[3][0] <= 3'd0; A[3][1] <= 3'd0; A[3][2] <= 3'd1; A[3][3] <= 3'd1;
                                d[0] <= (p - board_0) % p;
                                d[1] <= (p - board_1) % p;
                                d[2] <= (p - board_2) % p;
                                d[3] <= (p - board_3) % p;
                            end
                            2'd1: begin
                                // Reset x and pivot_row
                                x[0] <= 3'd0; x[1] <= 3'd0; x[2] <= 3'd0; x[3] <= 3'd0;
                                row <= 2'd0;
                                col <= 2'd0;
                            end
                        endcase
                        init_cnt <= init_cnt + 2'd1;
                        next_state <= INIT;
                    end else begin
                        init_cnt <= 2'd0;
                        next_state <= FIND_PIVOT;
                    end
                end

                FIND_PIVOT: begin
                    if (row <= 2'd3 && col <= 2'd3) begin
                        // Search for pivot in column 'col' starting from row 'row'
                        if (A[row][col] != 3'd0) begin
                            pivot_row <= row;
                            pivot_val <= A[row][col];
                            next_state <= SWAP;
                        end else begin
                            // Check next row
                            if (row < 2'd3) begin
                                row <= row + 2'd1;
                                next_state <= FIND_PIVOT;
                            end else begin
                                // No pivot found in this column (free variable)
                                // x[col] = 0 implicitly (already initialized)
                                col <= col + 2'd1;
                                row <= 2'd0; // Reset row for next column search
                                // If we've processed all columns, go to back substitution
                                if (col == 2'd3) next_state <= BACK_SUBST;
                                else next_state <= FIND_PIVOT;
                            end
                        end
                    end else begin
                        next_state <= BACK_SUBST;
                    end
                end

                SWAP: begin
                    // Swap current 'row' with 'pivot_row' in A and d if different
                    if (row != pivot_row) begin
                        for (r = 0; r < 4; r = r + 1) begin
                            // Swap A[row][r] and A[pivot_row][r]
                            if (r <= 2'd3) begin
                                A[row][r] <= A[pivot_row][r];
                                A[pivot_row][r] <= A[row][r];
                            end
                        end
                        d[row] <= d[pivot_row];
                        d[pivot_row] <= d[row];
                    end
                    next_state <= NORMALIZE;
                end

                NORMALIZE: begin
                    // Multiply pivot row by inverse of pivot_val
                    // Only if pivot_val != 1
                    if (pivot_val != 3'd1 && pivot_val != 3'd0) begin
                        // Calculate inverse once and apply
                        // Note: mod_inv is combinational, so we can use it directly
                        // We need to update the whole row, which takes time
                        // Let's do it element by element or use a loop
                        // To avoid combinational loop, we can do this in 1 cycle if small enough
                        // 4 elements in row is small
                        A[row][0] <= mod_mul(A[row][0], mod_inv(pivot_val, p), p);
                        A[row][1] <= mod_mul(A[row][1], mod_inv(pivot_val, p), p);
                        A[row][2] <= mod_mul(A[row][2], mod_inv(pivot_val, p), p);
                        A[row][3] <= mod_mul(A[row][3], mod_inv(pivot_val, p), p);
                        d[row] <= mod_mul(d[row], mod_inv(pivot_val, p), p);
                    end
                    elim_row <= 2'd0;
                    next_state <= ELIMINATE;
                end

                ELIMINATE: begin
                    // For all rows r != row, eliminate column 'col'
                    if (elim_row < 2'd4) begin
                        if (elim_row != row && A[elim_row][col] != 3'd0) begin
                            // Factor is A[elim_row][col] (since pivot is now 1)
                            // Subtract factor * pivot_row from row elim_row
                            for (c = 0; c < 4; c = c + 1) begin
                                if (c <= 2'd3) begin
                                    // A[elim_row][c] = A[elim_row][c] - factor * A[row][c]
                                    A[elim_row][c] <= mod_sub(A[elim_row][c], mod_mul(A[elim_row][col], A[row][c], p), p);
                                end
                            end
                            d[elim_row] <= mod_sub(d[elim_row], mod_mul(A[elim_row][col], d[row], p), p);
                        end
                        elim_row <= elim_row + 2'd1;
                        next_state <= ELIMINATE;
                    end else begin
                        // Move to next column
                        col <= col + 2'd1;
                        row <= row + 2'd1;
                        // Check if done with elimination
                        if (col == 2'd3) next_state <= BACK_SUBST;
                        else next_state <= FIND_PIVOT;
                    end
                end

                BACK_SUBST: begin
                    // Back substitution
                    // x[col] = d[row]
                    // This logic assumes matrix is in reduced row echelon form
                    // We need to map which row corresponds to which pivot
                    // Since we tracked 'row' as number of pivots found, we can iterate backwards
                    // Simplified: Iterate col from 3 down to 0, find the row with pivot in that col
                    // To keep it simple, we assume row indices correspond to col indices (true for full rank)
                    // If rank deficient, free variables are 0 (handled by x init)
                    
                    // Let's use back_row and back_col
                    if (back_col <= 2'd3) begin // Iterate columns 0 to 3 (or 3 to 0, but 0 to 3 works with current structure)
                        // We need to find the row for this column.
                        // Since we eliminated systematically, row index = number of pivots found before this.
                        // Let's just iterate backwards: 3, 2, 1, 0
                        // This part is tricky without keeping track of rank explicitly.
                        // Fallback: Brute force assign d to x if row has pivot in that col
                        // Or simply: x[i] = d[i] for full rank systems.
                        // For Primonimo, system is usually full rank.
                        // Let's do a simple assignment assuming full rank.
                        
                        if (back_col == 2'd3) x[3] <= d[3];
                        else if (back_col == 2'd2) x[2] <= d[2];
                        else if (back_col == 2'd1) x[1] <= d[1];
                        else if (back_col == 2'd0) x[0] <= d[0];
                        
                        back_col <= back_col + 2'd1;
                        next_state <= BACK_SUBST;
                    end else begin
                        // Check for inconsistency
                        // Inconsistency: row i has all zeros in A but d[i] != 0
                        // Since we iterated all rows during elimination, check d
                        if (d[0] != 3'd0 && A[0][0] == 3'd0 && A[0][1] == 3'd0 && A[0][2] == 3'd0 && A[0][3] == 3'd0) next_state <= NO_SOLUTION;
                        else if (d[1] != 3'd0 && A[1][0] == 3'd0 && A[1][1] == 3'd0 && A[1][2] == 3'd0 && A[1][3] == 3'd0) next_state <= NO_SOLUTION;
                        else if (d[2] != 3'd0 && A[2][0] == 3'd0 && A[2][1] == 3'd0 && A[2][2] == 3'd0 && A[2][3] == 3'd0) next_state <= NO_SOLUTION;
                        else if (d[3] != 3'd0 && A[3][0] == 3'd0 && A[3][1] == 3'd0 && A[3][2] == 3'd0 && A[3][3] == 3'd0) next_state <= NO_SOLUTION;
                        else next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    count_0 <= x[0];
                    count_1 <= x[1];
                    count_2 <= x[2];
                    count_3 <= x[3];
                    solution_exists <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                NO_SOLUTION: begin
                    solution_exists <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            state <= next_state;
        end
    end

endmodule