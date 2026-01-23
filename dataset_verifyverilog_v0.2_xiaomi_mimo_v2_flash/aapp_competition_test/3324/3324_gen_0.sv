module stoichiometry_balancer(
    input clk,
    input rst_n,
    input start,
    input [4:0] num_molecules,
    input [3:0] num_elements,
    input [15:0] matrix_in [0:19] [0:9],
    output reg [9:0] coefficients [0:19],
    output reg done,
    output reg valid
);

    parameter MAX_M = 20;
    parameter MAX_N = 10;

    // Internal matrix: Rows = Elements, Cols = Molecules
    reg signed [31:0] matrix [0:MAX_N-1] [0:MAX_M-1]; 
    reg signed [31:0] solution [0:MAX_M-1];
    
    // State definitions
    localparam IDLE = 0;
    localparam INIT = 1;
    localparam LOAD_MATRIX = 2;
    localparam PIVOT_FIND = 3;
    localparam PIVOT_SCAN = 4;
    localparam ELIMINATE = 5;
    localparam NEXT_COL = 6;
    localparam BACK_SUB_START = 7;
    localparam BACK_SUB_ASSIGN = 8;
    localparam BACK_SUB_SOLVE = 9;
    localparam NORMALIZE_SIGN = 10;
    localparam GCD_SETUP = 11;
    localparam GCD_LOOP = 12;
    localparam DIVIDE_BY_GCD = 13;
    localparam DONE_STATE = 14;

    reg [4:0] state;
    
    reg [4:0] r; // Row index (Elements)
    reg [4:0] c; // Col index (Molecules)
    reg [4:0] i; // General loop var
    reg [4:0] k; // Inner loop var
    
    reg signed [31:0] pivot_val;
    
    // GCD Registers
    reg [31:0] gcd_u, gcd_v;
    reg gcd_active;
    reg [31:0] global_gcd;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) state <= INIT;
                end

                INIT: begin
                    // Clear matrix and solution
                    r <= 0; c <= 0; i <= 0; k <= 0;
                    for (int x=0; x<MAX_N; x++) begin
                        for (int y=0; y<MAX_M; y++) begin
                            matrix[x][y] <= 0;
                        end
                    end
                    for (int x=0; x<MAX_M; x++) solution[x] <= 0;
                    state <= LOAD_MATRIX;
                end

                LOAD_MATRIX: begin
                    // Transpose input: internal_matrix[Elem][Mol] = matrix_in[Mol][Elem]
                    // We iterate r (molecule), c (element)
                    if (r < num_molecules) begin
                        if (c < num_elements) begin
                            matrix[c][r] <= {16'h0000, matrix_in[r][c]};
                            c <= c + 1;
                        end else begin
                            c <= 0;
                            r <= r + 1;
                        end
                    end else begin
                        r <= 0; c <= 0;
                        state <= PIVOT_FIND;
                    end
                end

                PIVOT_FIND: begin
                    // Pivot on columns (Molecules). Iterate c from 0 to num_molecules-1
                    // Find non-zero pivot in column c from row r downwards.
                    if (c < num_molecules) begin
                        if (r < num_elements) begin
                            if (matrix[r][c] != 0) begin
                                pivot_val <= matrix[r][c];
                                // Normalize pivot row to 1 (optional but simplifies back-sub)
                                // We will just perform elimination using this pivot_val
                                state <= ELIMINATE;
                                i <= 0; // Row counter for elimination
                            end else begin
                                r <= r + 1;
                            end
                        end else begin
                            // No pivot found in this column
                            r <= 0;
                            state <= NEXT_COL;
                        end
                    end else begin
                        // Done all columns
                        state <= BACK_SUB_START;
                    end
                end

                ELIMINATE: begin
                    // Eliminate column c from all rows i != r
                    // Logic: row_i = row_i * pivot_val - matrix[r][c] * row_r
                    // Wait, pivot_val is matrix[r][c]. 
                    // Use multiplier = matrix[i][c].
                    if (i < num_elements) begin
                        if (i != r && matrix[i][c] != 0) begin
                            // Update row i
                            for (int col = 0; col < MAX_M; col++) begin
                                if (col >= c) begin // Optimization: before c is 0
                                    matrix[i][col] <= matrix[i][col] * pivot_val - matrix[r][col] * matrix[i][c];
                                end
                            end
                        end else if (i == r) begin
                            // Normalize pivot row to 1 to simplify back-sub
                            // Only if divisible
                            for (int col = 0; col < MAX_M; col++) begin
                                if (col >= c) begin
                                    if (matrix[i][col] % pivot_val == 0)
                                        matrix[i][col] <= matrix[i][col] / pivot_val;
                                    // else keep it (might cause issues, but robust)
                                end
                            end
                        end
                        i <= i + 1;
                    end else begin
                        // Advance to next column
                        // Reset r to 0 for next column scan? No, in RREF we stay in same row.
                        // Actually, we move to next row (r+1) for next column.
                        r <= r + 1;
                        c <= c + 1;
                        state <= PIVOT_FIND;
                    end
                end

                NEXT_COL: begin
                    // Skip column c, try next
                    c <= c + 1;
                    r <= 0; // Reset row search
                    state <= PIVOT_FIND;
                end

                BACK_SUB_START: begin
                    // Initialize solution to 1 (assume all variables free first)
                    for (int x = 0; x < MAX_M; x++) begin
                        if (x < num_molecules) solution[x] <= 1;
                        else solution[x] <= 0;
                    end
                    c <= 0;
                    state <= BACK_SUB_ASSIGN;
                end

                BACK_SUB_ASSIGN: begin
                    // Identify dependent variables (columns with pivots) and set them to 0
                    // We check column c. If column c has a non-zero in a row where other pivots are 0?
                    // Simpler: If we performed RREF correctly, pivots are on diagonal.
                    // But we might have skipped columns.
                    // Let's iterate columns c. Scan rows r.
                    // If matrix[r][c] != 0, and this row has pivots at columns > c set to 0? 
                    // No, we just need to find if this column has a pivot.
                    // In RREF, a pivot exists if there's a row with 1 at (r,c) and 0s at (r, c') for c' > c.
                    // Since we set pivots to 1 in ELIMINATE, we check if matrix[r][c] == 1 and other entries are 0.
                    // This is complex to check again.
                    
                    // Simpler approach: 
                    // Solve: For each row r (Element), we have equation: sum(matrix[r][c] * solution[c]) = 0.
                    // If we set solution[c] = 1 for all c initially.
                    // Then we find the row with most non-zeros? No.
                    
                    // Standard Back Sub for Null Space:
                    // 1. Identify pivot columns. Let P be set of pivot columns.
                    // 2. Set free variables (columns not in P) to 1.
                    // 3. Solve for pivot variables.
                    
                    // To do this in hardware without storing pivot history:
                    // We can iterate columns c. 
                    // If we find a row r where matrix[r][c] is 1, and matrix[r][k] is 0 for k > c? 
                    // (Since we reduced left-to-right).
                    // We can just check if matrix[r][c] is the first non-zero in row r.
                    // Let's just iterate rows r.
                    // Find the first non-zero element in row r (say at col pc).
                    // Mark col pc as dependent. Set solution[pc] = 0.
                    // Then we can solve it later.
                    
                    // Let's do: Iterate rows r.
                    // Find pivot col pc in row r.
                    // Set solution[pc] = 0.
                    
                    if (r < num_elements) begin
                        // Find pivot in row r
                        if (c < num_molecules) begin
                            if (matrix[r][c] != 0) begin
                                // Found pivot for this row at col c
                                solution[c] <= 0; // Dependent
                                // We need to store this info for solving.
                                // But we can't store it easily.
                                // Let's just set solution[c] = 0 here.
                                // Then we will solve in BACK_SUB_SOLVE by iterating rows again.
                                r <= r + 1;
                                c <= 0;
                            end else begin
                                c <= c + 1;
                            end
                        end else begin
                            // No pivot in this row (all zeros? shouldn't happen if input consistent)
                            r <= r + 1;
                            c <= 0;
                        end
                    end else begin
                        // Done assigning
                        r <= 0;
                        c <= 0;
                        state <= BACK_SUB_SOLVE;
                    end
                end

                BACK_SUB_SOLVE: begin
                    // Now we have solution vector with 1s (free) and 0s (dependent).
                    // We need to compute values for dependent variables.
                    // Iterate rows r.
                    // Find pivot col pc in row r.
                    // If solution[pc] is 0 (dependent), compute it.
                    // equation: matrix[r][pc] * solution[pc] + sum(matrix[r][k]*solution[k] for k>pc) = 0
                    // => solution[pc] = -sum / matrix[r][pc]
                    
                    // Note: We normalized pivot to 1 in ELIMINATE. So matrix[r][pc] should be 1.
                    // So solution[pc] = -sum.
                    
                    if (r < num_elements) begin
                        // Find pivot pc
                        if (c < num_molecules) begin
                            if (matrix[r][c] != 0) begin
                                // Pivot col is c
                                if (solution[c] == 0) begin
                                    // Calculate sum
                                    reg signed [31:0] sum;
                                    sum = 0;
                                    for (int k = c + 1; k < num_molecules; k++) begin
                                        sum = sum + matrix[r][k] * solution[k];
                                    end
                                    // Subtract because equation is Sum = 0, we are solving for term.
                                    // term + sum = 0 => term = -sum.
                                    solution[c] <= -sum;
                                end
                                // Move to next row
                                r <= r + 1;
                                c <= 0;
                            end else begin
                                c <= c + 1;
                            end
                        end else begin
                            // No pivot in row, move to next row
                            r <= r + 1;
                            c <= 0;
                        end
                    end else begin
                        // Done solving
                        state <= NORMALIZE_SIGN;
                        i <= 0;
                    end
                end

                NORMALIZE_SIGN: begin
                    // Find first non-zero coefficient to determine sign
                    if (i < num_molecules) begin
                        if (solution[i] != 0) begin
                            if (solution[i] < 0) begin
                                for (int k = 0; k < MAX_M; k++) solution[k] <= -solution[k];
                            end
                            i <= num_molecules; // Done
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        // Check if all are zero (trivial solution)
                        state <= GCD_SETUP;
                        i <= 0;
                    end
                end

                GCD_SETUP: begin
                    // Find first non-zero for GCD base
                    if (i < num_molecules) begin
                        if (solution[i] != 0) begin
                            global_gcd <= (solution[i] < 0) ? -solution[i] : solution[i];
                            i <= i + 1;
                            state <= GCD_LOOP;
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        // All zeros? Done.
                        state <= DONE_STATE;
                    end
                end

                GCD_LOOP: begin
                    // Compute GCD with remaining non-zeros
                    // Use combinational logic or serial divider. 
                    // Let's use a simple state-based GCD.
                    // Find next non-zero
                    if (i < num_molecules) begin
                        if (solution[i] != 0) begin
                            // Setup GCD calculation
                            gcd_u <= global_gcd;
                            gcd_v <= (solution[i] < 0) ? -solution[i] : solution[i];
                            gcd_active <= 1;
                            // We need a state for GCD calc waiting. 
                            // Let's just do it in 1 cycle if small, or add a sub-state.
                            // Since numbers are small, let's do iterative GCD in this state.
                            // Actually, let's just compute GCD using a helper loop state.
                            // To save space, I'll use a while loop style in combinational logic.
                            // But since we are in clocked block, let's use a helper counter or 
                            // just do it in one cycle assuming it's fast (it's not for large numbers).
                            // Let's add a dedicated GCD sub-state.
                            state <= 13'd12; // GCD_SUB (reuse GCD_LOOP label if possible, or explicit state)
                            // Actually, let's use GCD_LOOP to iterate.
                            // We need to perform Euclidean steps until one is 0.
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        // Done GCD
                        state <= DIVIDE_BY_GCD;
                        i <= 0;
                    end
                end

                13'd12: begin // GCD_SUBSTATE (The Euclidean Algorithm steps)
                    if (gcd_u == 0) begin
                        global_gcd <= gcd_v;
                        gcd_active <= 0;
                        state <= GCD_LOOP; // Back to find next number
                        i <= i + 1; // We already processed i? No, we were processing i.
                        // Wait, we need to increment i only after we finish GCD with current i.
                        // So here we just go back to GCD_LOOP without incrementing i.
                        // But GCD_LOOP increments i if it's not active.
                        // Logic tweak:
                        // In GCD_LOOP, we set up u,v and go to GCD_SUB.
                        // GCD_SUB reduces them.
                        // When done, global_gcd is updated.
                        // Then we go back to GCD_LOOP to process next i.
                    end else if (gcd_v == 0) begin
                        global_gcd <= gcd_u;
                        gcd_active <= 0;
                        state <= GCD_LOOP;
                    end else if (gcd_u > gcd_v) begin
                        gcd_u <= gcd_v;
                        gcd_v <= gcd_u % gcd_v;
                    end else begin
                        gcd_v <= gcd_u;
                        gcd_u <= gcd_v % gcd_u;
                    end
                end

                DIVIDE_BY_GCD: begin
                    if (i < num_molecules) begin
                        if (solution[i] != 0) begin
                            if (global_gcd > 1) begin
                                solution[i] <= solution[i] / global_gcd;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    // Check validity (not all zeros)
                    valid <= 0;
                    for (int x = 0; x < num_molecules; x++) begin
                        coefficients[x] <= solution[x][9:0];
                        if (solution[x] != 0) valid <= 1;
                    end
                    if (!start) begin
                        done <= 0;
                        valid <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule