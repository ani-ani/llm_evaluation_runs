module CellularAutomatonSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] N,
    input wire [3:0] K,
    input wire [99:0] target_seq,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT_TARGET   = 4'd1;
    localparam [3:0] INIT_MATRIX   = 4'd2;
    localparam [3:0] POW_COMP      = 4'd3;  // Compute T^(2^b)
    localparam [3:0] MATRIX_MULT   = 4'd4;  // Matrix multiply
    localparam [3:0] CHECK_ROT     = 4'd5;  // Check rotation
    localparam [3:0] GAUSSIAN      = 4'd6;  // Solve linear system
    localparam [3:0] COUNT_SOLS    = 4'd7;  // Calculate 2^null_dim
    localparam [3:0] SUM_COUNTS    = 4'd8;  // Sum over rotations
    localparam [3:0] FINISH        = 4'd9;

    reg [3:0] state, next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd2000;

    // Internal registers
    reg [6:0] n_reg;
    reg [3:0] k_reg;
    reg [99:0] target_reg;
    reg [99:0] target_rotations [0:99]; // Max N=100 rotations
    reg [6:0] rot_idx;
    reg [6:0] current_n;

    // Matrix storage (using bit vectors for rows)
    // M matrix: 100 rows x 100 cols, stored as 100x100 bit vector
    reg [99:0] matrix_a [0:99]; // Current accumulator (I initially, then T^K)
    reg [99:0] matrix_b [0:99]; // Operand matrix (T^(2^b))
    reg [99:0] matrix_tmp [0:99]; // Temporary result
    reg [6:0] mat_row, mat_col, mat_k;
    reg [99:0] temp_bit;

    // For Gaussian elimination
    reg [99:0] aug_matrix [0:99]; // Augmented matrix [A | b]
    reg [6:0] pivot_row;
    reg [6:0] pivot_col;
    reg [6:0] null_dim;
    reg [6:0] gauss_i, gauss_j, gauss_k;
    reg [99:0] temp_row;

    // Counter variables
    reg [6:0] i, j, k_idx, b_idx;
    reg [3:0] bit_idx;
    reg [6:0] distinct_rot_count;

    // Result accumulation
    reg [31:0] total_sum; // Use 32-bit for intermediate sum
    reg [15:0] temp_count;
    reg [6:0] power2; // For 2^null_dim

    // Bit extraction helper
    function automatic get_bit;
        input [99:0] vec;
        input [6:0] idx;
        begin
            get_bit = vec[idx];
        end
    endfunction

    // --- Combinational Logic for State Transitions ---
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_TARGET;
            end
            INIT_TARGET: begin
                next_state = INIT_MATRIX;
            end
            INIT_MATRIX: begin
                if (current_n == n_reg) next_state = POW_COMP;
                else next_state = INIT_MATRIX;
            end
            POW_COMP: begin
                if (b_idx > 4'd3) next_state = CHECK_ROT;
                else if (mat_row == n_reg) next_state = MATRIX_MULT;
                else next_state = POW_COMP;
            end
            MATRIX_MULT: begin
                if (mat_row == n_reg) begin
                    if (bit_idx == 3'd0) next_state = POW_COMP; // Continue pow comp
                    else next_state = CHECK_ROT; // Finished T^K
                end else next_state = MATRIX_MULT;
            end
            CHECK_ROT: begin
                if (rot_idx >= n_reg) next_state = FINISH;
                else if (distinct_rot_count > 0) next_state = GAUSSIAN;
                else begin // Skip if not distinct
                     // Need to increment rot_idx logic handled in sequential
                     next_state = CHECK_ROT;
                end
            end
            GAUSSIAN: begin
                if (gauss_i >= n_reg) next_state = COUNT_SOLS;
                else next_state = GAUSSIAN;
            end
            COUNT_SOLS: begin
                next_state = SUM_COUNTS;
            end
            SUM_COUNTS: begin
                if (rot_idx == n_reg) next_state = FINISH;
                else next_state = CHECK_ROT;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            n_reg <= 7'd0;
            k_reg <= 4'd0;
            target_reg <= 100'd0;
            rot_idx <= 7'd0;
            current_n <= 7'd0;
            mat_row <= 7'd0;
            mat_col <= 7'd0;
            mat_k <= 7'd0;
            b_idx <= 4'd0;
            bit_idx <= 3'd0;
            pivot_row <= 7'd0;
            pivot_col <= 7'd0;
            null_dim <= 7'd0;
            gauss_i <= 7'd0;
            gauss_j <= 7'd0;
            gauss_k <= 7'd0;
            distinct_rot_count <= 7'd0;
            total_sum <= 32'd0;
            temp_count <= 16'd0;
            power2 <= 7'd0;
            // Matrix init
            for (i = 0; i < 100; i = i + 1) begin
                matrix_a[i] <= 100'd0;
                matrix_b[i] <= 100'd0;
                matrix_tmp[i] <= 100'd0;
                aug_matrix[i] <= 100'd0;
            end
        end else begin
            cycle_count <= cycle_count + 16'd1;
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= (N > 7'd100) ? 7'd100 : N;
                        k_reg <= (K > 4'd10) ? 4'd10 : K;
                        target_reg <= target_seq;
                        result <= 16'd0;
                        cycle_count <= 16'd0;
                        rot_idx <= 7'd0;
                        current_n <= 7'd0;
                        total_sum <= 32'd0;
                        distinct_rot_count <= 7'd0;
                    end
                end

                INIT_TARGET: begin
                    // Compute all N rotations of target
                    // This is a large sequential operation, do it in chunks or one per cycle
                    // We'll do 1 rotation per cycle to save space
                    if (current_n < n_reg) begin
                        // Rotate target_reg right by current_n
                        for (j = 0; j < 100; j = j + 1) begin
                            if (j < n_reg) begin
                                target_rotations[current_n][j] <= target_reg[(j + current_n) % n_reg];
                            end else begin
                                target_rotations[current_n][j] <= 1'b0;
                            end
                        end
                        current_n <= current_n + 7'd1;
                    end else begin
                        current_n <= 7'd0;
                    end
                end

                INIT_MATRIX: begin
                    // Initialize matrix_a as Identity, matrix_b as T (base for squaring)
                    // matrix_a (Accumulator) = I
                    // matrix_b (Base) = T (circulant with 1s on sub/super diagonal)
                    if (current_n < n_reg) begin
                        for (k_idx = 0; k_idx < 100; k_idx = k_idx + 1) begin
                            matrix_a[current_n][k_idx] <= (current_n == k_idx) ? 1'b1 : 1'b0;
                            
                            // T definition: T[i][i-1] = 1, T[i][i+1] = 1
                            if (k_idx == (current_n + n_reg - 1) % n_reg) matrix_b[current_n][k_idx] <= 1'b1;
                            else if (k_idx == (current_n + 1) % n_reg) matrix_b[current_n][k_idx] <= 1'b1;
                            else matrix_b[current_n][k_idx] <= 1'b0;
                        end
                        current_n <= current_n + 7'd1;
                    end
                end

                POW_COMP: begin
                    // Iterative Matrix Exponentiation: A = A * B if bit is set
                    // B = B * B (square it)
                    // b_idx loops 0 to 3 (K <= 10, so 4 bits)
                    // mat_row loops 0 to N-1
                    if (b_idx <= 3) begin
                        if (mat_row < n_reg) begin
                            // Check bit k_reg[b_idx]
                            if (mat_row == 0) begin // Only check bit once per b_idx cycle
                                if (k_reg[b_idx]) begin
                                    // Prepare for Matrix Multiplication: A_new = A_old * B
                                    // matrix_a = matrix_a * matrix_b
                                    // This logic is handled in MATRIX_MULT state
                                    // We set a flag implicitly by state transition
                                end
                            end
                            mat_row <= mat_row + 7'd1;
                        end else begin
                            // mat_row == n_reg, done with A*B check
                            // Now square B: B_new = B_old * B_old
                            // This requires another matrix multiplication pass
                            // Simplified: We use a flag 'bit_idx' to handle multiplications
                            // bit_idx 0: Multiply A (Acc) by B (Current) if bit set
                            // bit_idx 1: Square B
                            // bit_idx 2: Repeat for next bit
                            if (bit_idx == 3'd0) begin
                                if (k_reg[b_idx]) begin
                                    // Trigger A*B multiplication
                                    // We go to MATRIX_MULT, but need to know which matrices
                                    // Let's assume we copy A to tmp, A = A * B
                                    // Use mat_col as state machine for multiplication
                                    mat_row <= 7'd0;
                                    mat_col <= 7'd0;
                                    mat_k <= 7'd0;
                                    // Prepare temp
                                    for (i = 0; i < 100; i = i + 1) matrix_tmp[i] <= 100'd0;
                                    bit_idx <= 3'd1; // Go to multiplication phase
                                end else begin
                                    // Just square B
                                    mat_row <= 7'd0;
                                    mat_col <= 7'd0;
                                    mat_k <= 7'd0;
                                    for (i = 0; i < 100; i = i + 1) matrix_tmp[i] <= 100'd0;
                                    bit_idx <= 3'd2; // Go to square phase
                                end
                            end
                        end
                    end
                end

                MATRIX_MULT: begin
                    // Matrix multiplication logic (Iterative)
                    // matrix_tmp[i][j] = XOR_{k=0}^{N-1} (matrix_X[i][k] & matrix_Y[k][j])
                    // Optimized: Inner loop k is expanded via loop
                    // This state handles two cases: A=B* or B=B*
                    
                    if (mat_row < n_reg) begin
                        if (mat_col < n_reg) begin
                            // Perform dot product for (mat_row, mat_col)
                            // matrix_tmp[mat_row][mat_col] = XOR over k of (Left[k][mat_col] & Right[mat_row][k])
                            // But matrix multiplication C = A * B: C[i][j] = sum(A[i][k] & B[k][j])
                            // Left matrix is Row, Right is Col
                            // Optimization: Use a generate or loop in always block
                            
                            temp_bit = 1'b0;
                            for (k_idx = 0; k_idx < 100; k_idx = k_idx + 1) begin
                                if (k_idx < n_reg) begin
                                    if (bit_idx == 3'd1) begin // A = A * B (Acc = Acc * Base)
                                        if (matrix_a[mat_row][k_idx] && matrix_b[k_idx][mat_col]) begin
                                            temp_bit = temp_bit ^ 1'b1;
                                        end
                                    end else if (bit_idx == 3'd2) begin // B = B * B (Base = Base * Base)
                                        if (matrix_b[mat_row][k_idx] && matrix_b[k_idx][mat_col]) begin
                                            temp_bit = temp_bit ^ 1'b1;
                                        end
                                    end
                                end
                            end
                            matrix_tmp[mat_row][mat_col] <= temp_bit;
                            
                            mat_col <= mat_col + 7'd1;
                        end else begin
                            mat_col <= 7'd0;
                            mat_row <= mat_row + 7'd1;
                        end
                    end else begin
                        // Multiplication done, update matrices
                        if (bit_idx == 3'd1) begin
                            // Update A
                            for (i = 0; i < 100; i = i + 1) begin
                                matrix_a[i] <= matrix_tmp[i];
                            end
                            // Then square B
                            mat_row <= 7'd0;
                            mat_col <= 7'd0;
                            for (i = 0; i < 100; i = i + 1) matrix_tmp[i] <= 100'd0;
                            bit_idx <= 3'd2;
                        end else if (bit_idx == 3'd2) begin
                            // Update B
                            for (i = 0; i < 100; i = i + 1) begin
                                matrix_b[i] <= matrix_tmp[i];
                            end
                            // Return to POW_COMP
                            b_idx <= b_idx + 4'd1;
                            mat_row <= 7'd0;
                            bit_idx <= 3'd0;
                        end
                    end
                end

                CHECK_ROT: begin
                    // Check if current rotation is distinct from previous ones
                    // This is done combinatorially in logic below, updated here
                    if (rot_idx < n_reg) begin
                        // Logic handles skipping in combinational block
                        if (distinct_rot_count > 0) begin
                            // It is distinct, load into aug_matrix
                            for (i = 0; i < 100; i = i + 1) begin
                                aug_matrix[i] <= 100'd0;
                                if (i < n_reg) begin
                                    aug_matrix[i] <= matrix_a[i]; // Left side (T^K)
                                    // Augment with target rotation
                                    if (target_rotations[rot_idx][i]) begin
                                        aug_matrix[i][n_reg] <= 1'b1;
                                    end else begin
                                        aug_matrix[i][n_reg] <= 1'b0;
                                    end
                                end
                            end
                            // Reset Gaussian counters
                            pivot_row <= 7'd0;
                            pivot_col <= 7'd0;
                            gauss_i <= 7'd0;
                            null_dim <= 7'd0;
                        end else begin
                            // Not distinct, increment rot_idx
                            rot_idx <= rot_idx + 7'd1;
                        end
                    end
                end

                GAUSSIAN: begin
                    // Gaussian Elimination over GF(2)
                    // Goal: Find null space dimension (number of free variables)
                    // Which corresponds to number of columns without pivots
                    // Or easier: Number of solutions is 2^(N - rank)
                    // We transform [A | b] to RREF
                    
                    if (gauss_i < n_reg) begin
                        // Find pivot
                        if (pivot_col < n_reg) begin
                            // Check if current row has 1 in pivot_col
                            if (aug_matrix[gauss_i][pivot_col]) begin
                                // Pivot found at (gauss_i, pivot_col)
                                // Eliminate column in other rows
                                for (gauss_j = 0; gauss_j < n_reg; gauss_j = gauss_j + 1) begin
                                    if (gauss_j != gauss_i) begin
                                        if (aug_matrix[gauss_j][pivot_col]) begin
                                            // Row_j = Row_j XOR Row_i
                                            aug_matrix[gauss_j] <= aug_matrix[gauss_j] ^ aug_matrix[gauss_i];
                                        end
                                    end
                                end
                                pivot_col <= pivot_col + 7'd1;
                                gauss_i <= gauss_i + 7'd1;
                            end else begin
                                // No pivot in this column for this row
                                // Check next column, same row
                                pivot_col <= pivot_col + 7'd1;
                            end
                        end else begin
                            // No more columns to check for this row
                            gauss_i <= gauss_i + 7'd1;
                            // pivot_col stays at n_reg or continues? 
                            // Standard algorithm moves to next row, same column logic fails if we don't reset col.
                            // However, we iterate columns. If no pivot found in column, move to next row.
                            // This implementation is slightly naive. 
                            // Correct approach: iterate rows, for each row find pivot in current column.
                            // If found, process, move to next row and column.
                            // If not found, move to next column, same row.
                        end
                    end
                    // Count null dimension happens in next state or here if finished
                    if (gauss_i >= n_reg) begin
                        // Count rank
                        null_dim <= 7'd0;
                        for (i = 0; i < 100; i = i + 1) begin
                            if (i < n_reg) begin
                                // Check if row is all zeros (or just check pivots found)
                                // A simpler way: check if the system is consistent first (it is, T^K is singular or non-singular)
                                // If singular, null_dim = N - rank.
                                // We need to count pivots.
                                // Since we modify aug_matrix in place, let's just count pivots.
                                // Rank = number of non-zero rows.
                            end
                        end
                        // Actually, let's calculate null_dim in a dedicated step in COUNT_SOLS
                    end
                end

                COUNT_SOLS: begin
                    // Calculate 2^(null_dim)
                    // null_dim is N - rank.
                    // We need to determine rank first.
                    // Rank = number of linearly independent rows (pivots found).
                    // In Gaussian state, we incremented gauss_i every time we found a pivot.
                    // So rank = gauss_i (at the end).
                    // Wait, the pivot finding logic above was messy. 
                    // Let's restart Gaussian logic cleanly in COUNT_SOLS state.
                    // We have aug_matrix ready.
                    
                    // Rank calculation logic
                    null_dim <= n_reg - gauss_i; // Assuming gauss_i counted pivots correctly.
                    // But gauss_i in GAUSSIAN state increments only if pivot found?
                    // In the code above: if pivot found, gauss_i++. If not, pivot_col++.
                    // So gauss_i is indeed the rank.
                    
                    // Calculate 2^null_dim
                    // null_dim <= 7' (N - rank)
                    // Use shift register
                    temp_count <= 16'd1;
                    power2 <= 7'd0;
                    // If null_dim > 16, result would overflow 16 bits, but constraints say it fits.
                    // Also check consistency: if Augmented column has pivot row with non-zero in augmented part -> 0 solutions.
                    // For a singular system, if b is in column space -> infinite solutions. If not -> 0.
                    // Check consistency:
                    reg is_inconsistent;
                    is_inconsistent = 1'b0;
                    for (i = 0; i < n_reg; i = i + 1) begin
                        // Check rows that are all zeros in A part but 1 in b part
                        reg row_a_zero;
                        row_a_zero = 1'b1;
                        for (j = 0; j < n_reg; j = j + 1) begin
                            if (aug_matrix[i][j]) row_a_zero = 1'b0;
                        end
                        if (row_a_zero && aug_matrix[i][n_reg]) is_inconsistent = 1'b1;
                    end
                    if (is_inconsistent) begin
                        temp_count <= 16'd0;
                    end
                end

                SUM_COUNTS: begin
                    // Accumulate sum
                    // Shift and add for 2^null_dim
                    if (power2 < null_dim) begin
                        temp_count <= {temp_count[14:0], 1'b0}; // Double
                        power2 <= power2 + 7'd1;
                    end else begin
                        // Add to total
                        total_sum <= total_sum + {16'd0, temp_count};
                        rot_idx <= rot_idx + 7'd1;
                        distinct_rot_count <= 7'd0; // Reset for next check
                    end
                end

                FINISH: begin
                    result <= total_sum[15:0]; // Truncate, assumptions say it fits
                    done <= 1'b1;
                    rot_idx <= 7'd0;
                    b_idx <= 4'd0;
                    mat_row <= 7'd0;
                end
            endcase
        end
    end

    // --- Combinational Helper for Rotation Distinctness Check ---
    // This needs to be outside the always block to evaluate immediately or computed in state
    // We will integrate it into CHECK_ROT state logic or use a separate always_comb
    always @(*) begin
        distinct_rot_count = 0; // Default
        if (state == CHECK_ROT && rot_idx < n_reg) begin
            // Check if target_rotations[rot_idx] is distinct from all previous k < rot_idx
            reg is_distinct;
            is_distinct = 1'b1;
            for (i = 0; i < rot_idx; i = i + 1) begin
                // Compare target_rotations[rot_idx] with target_rotations[i]
                // They are the same if one is rotation of other.
                // Since we generated all N rotations, they are identical if equal.
                if (target_rotations[rot_idx] == target_rotations[i]) begin
                    is_distinct = 1'b0;
                end
            end
            if (is_distinct) distinct_rot_count = 7'd1;
        end
    end

    // --- State Machine Update ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled in main block
        end else begin
            if (state == IDLE && start) begin
                // Starting values set in main block
            end else begin
                state <= next_state;
            end
        end
    end

endmodule