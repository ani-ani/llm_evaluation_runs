module ChemicalBalance(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_valid,
    input wire [3:0] molecule_idx,
    input wire sign,
    input wire [3:0] num_elements,
    input wire [3:0] element_id,
    input wire [3:0] count,
    input wire [15:0] coeff_in,
    output reg result_valid,
    output reg [15:0] coeff_out,
    output reg done
);

    // State Definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CONFIG      = 3'd1;
    localparam [2:0] MATRIX_BUILD = 3'd2;
    localparam [2:0] SOLVE       = 3'd3;
    localparam [2:0] OUTPUT      = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    // Matrix Parameters
    localparam [3:0] MAX_MOLECULES = 4'd15;
    localparam [3:0] MAX_ELEMENTS  = 4'd9;
    localparam [3:0] MAX_ATOMS     = 4'd12;

    // Registers for State Machine
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Registers for Configuration
    reg [15:0] sign_reg [0:15];         // Store sign for each molecule
    reg [3:0] unique_elements [0:9];    // List of unique element IDs
    reg [3:0] num_unique_elements;
    reg [3:0] molecule_count;
    reg [15:0] matrix [0:9][0:15];      // Matrix A [elements][molecules]
    reg [15:0] solution [0:15];         // Solution coefficients X
    reg [15:0] temp_solution [0:15];    // Temporary solution for GCD
    reg [3:0] current_molecule;
    reg [3:0] current_element;
    reg [3:0] row_idx;
    reg [3:0] col_idx;
    reg [3:0] pivot_row;
    reg [3:0] output_idx;
    reg [15:0] gcd_val;
    reg [15:0] lcm_val;
    reg [31:0] temp_num;                // 32-bit for GCD calculations
    reg [31:0] temp_den;
    reg [15:0] common_divisor;
    reg [3:0] search_idx;
    reg found;
    reg [15:0] scale_factor;
    reg [31:0] mult_temp;
    reg [31:0] div_temp;
    reg [15:0] count_reg;
    reg [3:0] elem_id_reg;
    reg [15:0] sign_val;

    // Helper variables
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            coeff_out <= 16'd0;
            cycle_count <= 8'd0;
            num_unique_elements <= 4'd0;
            molecule_count <= 4'd0;
            current_molecule <= 4'd0;
            current_element <= 4'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            pivot_row <= 4'd0;
            output_idx <= 4'd0;
            gcd_val <= 16'd0;
            lcm_val <= 16'd0;
            temp_num <= 32'd0;
            temp_den <= 32'd0;
            common_divisor <= 16'd0;
            search_idx <= 4'd0;
            found <= 1'b0;
            scale_factor <= 16'd1;
            mult_temp <= 32'd0;
            div_temp <= 32'd0;
            count_reg <= 16'd0;
            elem_id_reg <= 4'd0;
            sign_val <= 16'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                sign_reg[i] <= 16'd0;
                solution[i] <= 16'd0;
                temp_solution[i] <= 16'd0;
            end
            for (i = 0; i < 10; i = i + 1) begin
                unique_elements[i] <= 4'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    matrix[i][j] <= 16'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Reset configuration registers
                        for (i = 0; i < 16; i = i + 1) begin
                            sign_reg[i] <= 16'd0;
                            solution[i] <= 16'd0;
                            temp_solution[i] <= 16'd0;
                        end
                        for (i = 0; i < 10; i = i + 1) begin
                            unique_elements[i] <= 4'd0;
                            for (j = 0; j < 16; j = j + 1) begin
                                matrix[i][j] <= 16'd0;
                            end
                        end
                        num_unique_elements <= 4'd0;
                        molecule_count <= 4'd0;
                    end
                end

                CONFIG: begin
                    if (config_valid) begin
                        // Check if molecule_idx is new
                        if (molecule_idx >= molecule_count) begin
                            molecule_count <= molecule_idx + 4'd1;
                        end
                        
                        // Store sign (1 for left, 0 for right -> map to +1/-1)
                        // We store as +1 or -1 for matrix construction
                        if (sign) begin
                            sign_reg[molecule_idx] <= 16'd1;
                        end else begin
                            sign_reg[molecule_idx] <= 16'hFFFF; // -1 in 16-bit signed
                        end
                        
                        // Check if element is already in unique list
                        found <= 1'b0;
                        for (i = 0; i < 10; i = i + 1) begin
                            if (unique_elements[i] == element_id && i < num_unique_elements) begin
                                found <= 1'b1;
                            end
                        end
                        
                        if (!found && num_unique_elements < 10) begin
                            unique_elements[num_unique_elements] <= element_id;
                            num_unique_elements <= num_unique_elements + 4'd1;
                        end
                        
                        // Update matrix (will be finalized in MATRIX_BUILD)
                        // We store temporarily, assuming element_id maps to row index
                        // In a real implementation, we'd need a lookup, but for simplicity
                        // we assume sequential input or use element_id as direct index if < 10
                        if (element_id < 10) begin
                            matrix[element_id][molecule_idx] <= {12'd0, count};
                        end
                    end
                end

                MATRIX_BUILD: begin
                    // Multiply matrix entries by sign
                    // A[i][j] = count * sign
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 10; j = j + 1) begin
                            if (j < num_unique_elements) begin
                                // Multiply count by sign
                                if (sign_reg[i] == 16'd1) begin
                                    matrix[j][i] <= matrix[j][i];
                                end else if (sign_reg[i] == 16'hFFFF) begin
                                    // Two's complement negation
                                    matrix[j][i] <= ~matrix[j][i] + 16'd1;
                                end
                            end
                        end
                    end
                    // Initialize pivot_row
                    pivot_row <= 4'd0;
                    col_idx <= 4'd0;
                end

                SOLVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Gauss-Jordan Elimination (Row Echelon Form)
                    // We operate on the matrix to find ratios
                    // Since it's 1D null space, we set last variable to 1 and solve
                    
                    if (col_idx < molecule_count && pivot_row < num_unique_elements) begin
                        // Find pivot
                        if (matrix[pivot_row][col_idx] == 16'd0) begin
                            // Swap rows if possible
                            // Simple search for non-zero in current column
                            for (i = pivot_row + 1; i < num_unique_elements; i = i + 1) begin
                                if (matrix[i][col_idx] != 16'd0) begin
                                    // Swap rows pivot_row and i
                                    for (j = 0; j < 16; j = j + 1) begin
                                        temp_solution[j] <= matrix[pivot_row][j];
                                        matrix[pivot_row][j] <= matrix[i][j];
                                        matrix[i][j] <= temp_solution[j];
                                    end
                                end
                            end
                        end
                        
                        // Normalize pivot row
                        if (matrix[pivot_row][col_idx] != 16'd0) begin
                            // Divide entire row by pivot value (use GCD for integer math)
                            // Simplified: We will use the pivot value as scale
                            scale_factor <= matrix[pivot_row][col_idx];
                            
                            // Eliminate below
                            for (i = pivot_row + 1; i < num_unique_elements; i = i + 1) begin
                                if (matrix[i][col_idx] != 16'd0) begin
                                    // Row i = Row i - (factor) * Row pivot
                                    // factor = matrix[i][col_idx] / matrix[pivot_row][col_idx]
                                    // Use LCM/GCD approach or Fixed Point
                                    // Here we use integer scaling to avoid floats
                                    // We multiply Row i by pivot, and Row pivot by matrix[i][col_idx]
                                    // Then subtract. This keeps integers but grows fast.
                                    // Alternative: Fixed Point Q16.16
                                    
                                    // Let's use a simpler approach for synthesis:
                                    // Just store the ratios for back substitution later
                                    // For now, we mark this as simplified
                                    // We will actually solve using Cramer's rule style or back-substitution
                                    
                                    // Actually, for the null space, we want to express variables in terms of free variable.
                                    // Let's assume the last molecule is the free variable (set to 1).
                                    // We need to back-substitute.
                                    
                                    // This section is complex. We will implement a simpler
                                    // iterative solver for ratios.
                                    
                                    // Reset to simple ratio calculation
                                end
                            end
                            pivot_row <= pivot_row + 4'd1;
                        end
                        col_idx <= col_idx + 4'd1;
                    end
                    
                    // Simplified Solver Logic for 1D Null Space:
                    // 1. Find LCM of all denominators from row operations
                    // 2. Assign arbitrary value (e.g., LCM) to one variable
                    // 3. Back-substitute to find others
                    // 4. Reduce by GCD
                    
                    // We will use a fixed-point approach for back substitution
                    // Iterative approach: Start with coeff[0] = 1, compute others,
                    // find LCM of denominators, multiply, reduce.
                    
                    // Let's use the state to drive specific solver steps
                    // Step A: Initialize solution with 1s
                    if (cycle_count == 8'd1) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < molecule_count) begin
                                solution[i] <= 16'd1; // Initial guess
                            end else begin
                                solution[i] <= 16'd0;
                            end
                        end
                    end
                    
                    // Step B: Iterative relaxation or ratio calculation
                    // For linear equations A*X = 0, we can use:
                    // X_j = - Sum(A_ij * X_i) / A_jj (for diagonal element j)
                    // We iterate until stable or fixed iterations.
                    
                    if (cycle_count > 8'd1 && cycle_count < 8'd50) begin
                        // Update one variable per cycle
                        if (current_element < num_unique_elements) begin
                            // Calculate sum of row * current solution
                            // We need to find which column dominates
                            // This is a simplified solver for 1D null space
                            // We assume matrix is rank deficient (rank = n-1)
                            
                            // Calculate weighted sum
                            // If we treat X[0] as 1, compute others.
                            // Actually, let's use Gaussian elimination with Q16.16
                            
                            // Re-implementing a robust solver loop:
                            // 1. Set X[molecule_count-1] = 1
                            // 2. For i from molecule_count-2 down to 0:
                            //    X[i] = - Sum(A[i][j] * X[j]) / A[i][i]
                            //    (Assuming A is upper triangular or diagonal)
                            
                            // To make it upper triangular, we need elimination.
                            // Let's do elimination now.
                            
                            // Elimination Loop
                            for (i = 0; i < num_unique_elements; i = i + 1) begin
                                // Pivot is matrix[i][i] (conceptually)
                                // We need to ensure non-zero pivot
                                if (matrix[i][i] == 16'd0) begin
                                    // Swap with later row
                                    for (j = i + 1; j < num_unique_elements; j = j + 1) begin
                                        if (matrix[j][i] != 16'd0) begin
                                            for (k = 0; k < 16; k = k + 1) begin
                                                temp_solution[k] <= matrix[i][k];
                                                matrix[i][k] <= matrix[j][k];
                                                matrix[j][k] <= temp_solution[k];
                                            end
                                        end
                                    end
                                end
                                
                                // Eliminate below
                                for (j = i + 1; j < num_unique_elements; j = j + 1) begin
                                    if (matrix[i][i] != 16'd0 && matrix[j][i] != 16'd0) begin
                                        // Scale factor = matrix[j][i] / matrix[i][i]
                                        // We use Q16.16 for scale
                                        // mult_temp = matrix[j][i] * 65536 / matrix[i][i]
                                        div_temp = (matrix[j][i] * 32'd65536) / matrix[i][i];
                                        // Subtract scaled row i from row j
                                        for (k = 0; k < 16; k = k + 1) begin
                                            // matrix[j][k] = matrix[j][k] - (div_temp * matrix[i][k] / 65536)
                                            mult_temp = div_temp * matrix[i][k];
                                            matrix[j][k] <= matrix[j][k] - mult_temp[31:16];
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    // Step C: Back Substitution
                    if (cycle_count >= 8'd50 && cycle_count < 8'd100) begin
                        // Set free variable (last molecule) to 1.0 in Q16.16
                        // We are solving for ratios.
                        // Let's use a fixed point buffer for solution
                        // sol_q16[i] = coefficient * 65536
                        
                        // Back substitute
                        // For i = num_unique_elements - 1 down to 0
                        // The equation is: Sum(A[i][j] * X[j]) = 0
                        // So X[i] = - Sum(A[i][j] * X[j]) / A[i][i] (for j > i)
                        
                        // We use a temporary array for Q16.16 solution
                        reg [31:0] sol_q16 [0:15];
                        
                        // Initialize last var to 1.0 (or LCM)
                        if (cycle_count == 8'd50) begin
                            for (i = 0; i < 16; i = i + 1) begin
                                sol_q16[i] <= 32'd0;
                            end
                            // Assume the last molecule (or free var) is set to 1
                            // But we need to find which variable is free.
                            // In null space, any variable can be free.
                            // Let's set the LAST molecule to 1.
                            if (molecule_count > 0) begin
                                sol_q16[molecule_count - 1] <= 32'd65536; // 1.0 in Q16.16
                            end
                        end else begin
                            // Iterate backwards
                            for (i = 0; i < num_unique_elements; i = i + 1) begin
                                // Assuming matrix is now upper triangular (pivots on diagonal)
                                // Find the row corresponding to element i (it might be swapped)
                                // Simplified: We assume row i corresponds to element i
                                // and pivot is at [i][i]
                                
                                // Calculate sum for row i
                                reg [31:0] row_sum;
                                row_sum = 32'd0;
                                for (j = i + 1; j < molecule_count; j = j + 1) begin
                                    // row_sum += A[i][j] * X[j]
                                    // A[i][j] is integer, X[j] is Q16.16
                                    mult_temp = matrix[i][j] * sol_q16[j];
                                    row_sum = row_sum + mult_temp; // Keep in Q32.32 roughly
                                end
                                
                                // X[i] = -row_sum / A[i][i]
                                if (matrix[i][i] != 16'd0) begin
                                    // Division: row_sum / A[i][i]
                                    // row_sum is Q32.32 (from multiplication), but we can shift
                                    // Result should be Q16.16
                                    // (row_sum >> 16) / matrix[i][i] * 65536
                                    // Actually: (row_sum / matrix[i][i])
                                    // row_sum is 64-bit conceptually, here 32-bit
                                    // We shift row_sum right by 16 to get Q16.16 from Q32.32
                                    div_temp = row_sum[31:0] / matrix[i][i];
                                    // div_temp is now roughly Q16.16 (result of (Q32.32 / int))
                                    // Negate
                                    sol_q16[i] <= -div_temp;
                                end
                            end
                        end
                        
                        // Copy back to solution (integer) and find LCM/GCD
                        // Store in temp_solution for now
                        for (i = 0; i < 16; i = i + 1) begin
                            temp_solution[i] <= sol_q16[i][31:16]; // Integer part
                        end
                    end
                    
                    // Step D: Scale to Integers and Reduce
                    if (cycle_count >= 8'd100 && cycle_count < 8'd150) begin
                        // Calculate LCM of denominators (fractional parts)
                        // But we used Q16.16, so we have integer ratios now (mostly).
                        // We need to clear fractions.
                        // If we used 1 as the free variable, the others might be fractions.
                        // We need to find a common multiplier.
                        
                        // Find LCM of denominators of temp_solution
                        // Since we are in integer domain, we assume temp_solution are already integers
                        // or close to it. We need to handle fractions if any.
                        // With Q16.16, we have fixed point.
                        // Let's assume we want integer results.
                        // We multiply everything by a factor to clear decimals, then divide by GCD.
                        
                        // A better approach for integer null space:
                        // Use Cramer's rule or matrix minors.
                        // Since we are at cycle_count > 100, let's finalize.
                        
                        // Let's assume temp_solution holds the ratios.
                        // We need to find the LCM of the denominators if they were fractions.
                        // Since we are in Verilog and constraints are loose, 
                        // we will assume temp_solution contains valid integers or 
                        // we perform a scaling operation.
                        
                        // Let's calculate the GCD of all values to reduce.
                        common_divisor <= temp_solution[0];
                        
                        // Find GCD of all coefficients
                        if (cycle_count > 8'd100 && cycle_count < 8'd120) begin
                            for (i = 1; i < molecule_count; i = i + 1) begin
                                // Euclidean algorithm for GCD
                                temp_num <= common_divisor;
                                temp_den <= temp_solution[i];
                                while (temp_den != 0) begin
                                    temp_num <= temp_den;
                                    temp_den <= temp_num % temp_den;
                                end
                                common_divisor <= temp_num;
                            end
                        end
                        
                        // Divide by GCD
                        if (cycle_count == 8'd120) begin
                            if (common_divisor != 0) begin
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (i < molecule_count) begin
                                        solution[i] <= temp_solution[i] / common_divisor;
                                    end
                                end
                            end else begin
                                // Fallback if GCD is 0
                                for (i = 0; i < 16; i = i + 1) begin
                                    solution[i] <= temp_solution[i];
                                end
                            end
                        end
                    end
                end

                OUTPUT: begin
                    // Output coefficients one by one
                    result_valid <= 1'b1;
                    coeff_out <= solution[output_idx];
                    
                    if (output_idx < molecule_count - 1) begin
                        output_idx <= output_idx + 4'd1;
                    end else begin
                        output_idx <= 4'd0;
                    end
                end

                FINISH: begin
                    result_valid <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CONFIG;
            
            CONFIG: begin
                // Transition when configuration is done.
                // We assume configuration phase ends when a specific command or timeout occurs.
                // Here, we transition if start is deasserted (single pulse) or by external control.
                // For simulation simplicity, we use a timeout or explicit signal.
                // Since the interface doesn't specify a config_done signal, 
                // we assume CONFIG continues until start goes low or internal timer.
                // Let's rely on the fact that start is a pulse.
                // We need a mechanism to exit CONFIG.
                // We will check if config_valid is low for a few cycles or use cycle count.
                // ASSUMPTION: CONFIG phase is controlled externally. 
                // If config_valid stops, we move to build.
                // However, to be robust, let's use a fixed cycle count or 
                // check if molecule_idx implies end (e.g., molecule_idx == 0 after data).
                // Let's say CONFIG ends when config_valid is low.
                if (!config_valid && molecule_count > 0) begin
                    next_state = MATRIX_BUILD;
                end
            end
            
            MATRIX_BUILD: begin
                // One cycle to process signs
                next_state = SOLVE;
            end
            
            SOLVE: begin
                // Wait for solver to finish
                if (cycle_count >= 8'd150) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                // Output for all molecules
                if (output_idx == molecule_count - 1 && result_valid) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                // Hold done for one cycle
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule