module xorbonacci_query (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k,
    input wire [63:0] init,
    input wire [63:0] l,
    input wire [63:0] r,
    output reg [63:0] result,
    output reg done
);

    // Constants and Local Parameters
    localparam [3:0] K_MAX = 4'd8;
    localparam [6:0] MAX_ITER = 7'd64;
    
    // FSM States
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] LOAD_INIT       = 4'd1;
    localparam [3:0] PREP_L_START     = 4'd2;
    localparam [3:0] CALC_L           = 4'd3;
    localparam [3:0] SAVE_L_SUM       = 4'd4;
    localparam [3:0] PREP_R_START     = 4'd5;
    localparam [3:0] CALC_R           = 4'd6;
    localparam [3:0] SAVE_R_SUM       = 4'd7;
    localparam [3:0] FINISH           = 4'd8;
    localparam [3:0] ERROR            = 4'd9;
    
    // State registers
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [2:0] k_reg; // K limited to 8
    reg [63:0] l_reg;
    reg [63:0] r_reg;
    
    // Initial terms array (8 elements, 8 bits each)
    reg [7:0] init_terms [0:7];
    
    // Matrix registers (8x8 binary)
    reg [7:0] mat_A [0:7]; // 8 rows, 8 columns each
    reg [7:0] mat_B [0:7];
    reg [7:0] mat_res [0:7];
    
    // Vector registers
    reg [7:0] vec_state [0:7]; // Current state vector (x_n, x_{n-1}, ...)
    reg [7:0] vec_result [0:7]; // Result of transformation
    
    // Prefix sums
    reg [7:0] sum_L [0:7];
    reg [7:0] sum_R [0:7];
    
    // Counter for exponentiation
    reg [5:0] bit_idx; // 0 to 63
    reg [2:0] col_idx; // 0 to 7
    reg [2:0] row_idx; // 0 to 7
    reg [2:0] dot_idx; // 0 to 7
    
    // Temporary accumulation for matrix multiplication
    reg acc_bit;
    
    // Helper signals for computation
    reg [7:0] target_exp;
    reg calc_done_flag;
    reg [1:0] op_mode; // 0: idle, 1: calc sum, 2: identity, 3: power of T
    
    // Control signals
    reg start_calc;
    reg loading_init;
    reg computing;
    reg [2:0] active_k;
    
    // Register initialization
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            k_reg <= 3'd0;
            l_reg <= 64'd0;
            r_reg <= 64'd0;
            bit_idx <= 6'd0;
            col_idx <= 3'd0;
            row_idx <= 3'd0;
            dot_idx <= 3'd0;
            start_calc <= 1'b0;
            active_k <= 3'd0;
            op_mode <= 2'd0;
            loading_init <= 1'b0;
            computing <= 1'b0;
            calc_done_flag <= 1'b0;
            
            // Clear arrays
            for (i = 0; i < 8; i = i + 1) begin
                init_terms[i] <= 8'd0;
                sum_L[i] <= 8'd0;
                sum_R[i] <= 8'd0;
                vec_state[i] <= 8'd0;
                vec_result[i] <= 8'd0;
                mat_A[i] <= 8'd0;
                mat_B[i] <= 8'd0;
                mat_res[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        k_reg <= (k > K_MAX) ? K_MAX : k[2:0];
                        l_reg <= l;
                        r_reg <= r;
                        loading_init <= 1'b1;
                    end
                end
                
                LOAD_INIT: begin
                    if (loading_init) begin
                        // Extract 8-bit terms from 64-bit init
                        // init[7:0] = term 0, init[15:8] = term 1, ...
                        init_terms[0] <= init[7:0];
                        init_terms[1] <= init[15:8];
                        init_terms[2] <= init[23:16];
                        init_terms[3] <= init[31:24];
                        init_terms[4] <= init[39:32];
                        init_terms[5] <= init[47:40];
                        init_terms[6] <= init[55:48];
                        init_terms[7] <= init[63:56];
                        loading_init <= 1'b0;
                        active_k <= k_reg;
                    end
                end
                
                PREP_L_START: begin
                    // Setup for L-1 calculation
                    bit_idx <= 6'd0;
                    op_mode <= 2'd2; // Start with Identity matrix
                    // Initialize accumulator matrices
                    for (i = 0; i < 8; i = i + 1) begin
                        mat_A[i] <= 8'd0;
                        if (i < 3'd8) begin
                            mat_A[i][i] <= 1'b1; // Identity
                            mat_B[i] <= 8'd0;
                        end else begin
                            mat_B[i] <= 8'd0;
                        end
                    end
                    // Setup B as transition matrix T
                    // T has ones at (0,i) for i=0..K-1 and (i, i-1) for i=1..K-1
                    // This is hardcoded for K=8 based on spec structure
                    // Row 0: [1, 1, 1, 1, 1, 1, 1, 1] (typical Fibonacci-like)
                    // Rows 1-7: [1, 0, 0, ...], [0, 1, 0, ...] etc.
                    // Actually, let's construct T based on K
                    // T is companion matrix for the recurrence
                    // x_n = x_{n-1} + x_{n-2} + ... + x_{n-K} (XOR sum)
                    // In binary, addition is XOR. So T[0][i] = 1 for i=0..K-1
                    // And T[i][i-1] = 1 for i=1..K-1
                    
                    // We load the Transition Matrix T into mat_B
                    // This depends on k_reg
                    mat_B[0] <= 8'hFF; // All ones for first row (masked later)
                    mat_B[1] <= 8'h02; // 00000010 (bit 1 set)
                    mat_B[2] <= 8'h04; // 00000100 (bit 2 set)
                    mat_B[3] <= 8'h08; // 00001000 (bit 3 set)
                    mat_B[4] <= 8'h10; // 00010000
                    mat_B[5] <= 8'h20; // 00100000
                    mat_B[6] <= 8'h40; // 01000000
                    mat_B[7] <= 8'h80; // 10000000
                end
                
                CALC_L: begin
                    if (computing) begin
                        // Matrix Multiplication: A = A * B (mod 2)
                        // Iterative: row_idx, col_idx, dot_idx
                        
                        if (dot_idx < active_k) begin
                            // Accumulate dot product for mat_res[row_idx][col_idx]
                            // Access bits: mat_A[row_idx][dot_idx] & mat_B[dot_idx][col_idx]
                            acc_bit <= acc_bit ^ 
                                       (mat_A[row_idx][dot_idx] & mat_B[dot_idx][col_idx]);
                            dot_idx <= dot_idx + 3'd1;
                        end else begin
                            // Finished dot product for one cell
                            if (acc_bit) mat_res[row_idx][col_idx] <= 1'b1;
                            else mat_res[row_idx][col_idx] <= 1'b0;
                            
                            // Reset accumulator for next cell
                            acc_bit <= 1'b0;
                            dot_idx <= 3'd0;
                            
                            // Move to next column or row
                            if (col_idx < active_k - 3'd1) begin
                                col_idx <= col_idx + 3'd1;
                            end else begin
                                col_idx <= 3'd0;
                                if (row_idx < active_k - 3'd1) begin
                                    row_idx <= row_idx + 3'd1;
                                end else begin
                                    // Finished matrix multiplication for one power of 2
                                    row_idx <= 3'd0;
                                    
                                    // If current bit in target_exp is set, multiply accumulator by result
                                    if (target_exp[bit_idx]) begin
                                        // A = A * mat_res (store in mat_A temporarily)
                                        // We need a separate multiplication step or reuse logic
                                        // For simplicity here, we copy mat_res to mat_B and multiply A * mat_res
                                        // But A is currently the accumulator. Let's swap pointers.
                                        for (i = 0; i < 8; i = i + 1) begin
                                            mat_B[i] <= mat_res[i];
                                        end
                                        op_mode <= 2'd3; // Next state will perform A * mat_res
                                    end else begin
                                        // Just update B for next iteration: B = B * B
                                        for (i = 0; i < 8; i = i + 1) begin
                                            mat_B[i] <= mat_res[i];
                                        end
                                        bit_idx <= bit_idx + 6'd1;
                                        if (bit_idx >= MAX_ITER - 6'd1) begin
                                            computing <= 1'b0;
                                            calc_done_flag <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                PREP_R_START: begin
                    // Similar to PREP_L_START
                    bit_idx <= 6'd0;
                    op_mode <= 2'd2; // Identity
                    for (i = 0; i < 8; i = i + 1) begin
                        mat_A[i] <= 8'd0;
                        if (i < 3'd8) mat_A[i][i] <= 1'b1;
                        mat_B[i] <= 8'd0;
                    end
                    // Reload Transition Matrix T into B
                    mat_B[0] <= 8'hFF;
                    mat_B[1] <= 8'h02;
                    mat_B[2] <= 8'h04;
                    mat_B[3] <= 8'h08;
                    mat_B[4] <= 8'h10;
                    mat_B[5] <= 8'h20;
                    mat_B[6] <= 8'h40;
                    mat_B[7] <= 8'h80;
                end
                
                CALC_R: begin
                    // Same logic as CALC_L
                    if (computing) begin
                        if (dot_idx < active_k) begin
                            acc_bit <= acc_bit ^ 
                                       (mat_A[row_idx][dot_idx] & mat_B[dot_idx][col_idx]);
                            dot_idx <= dot_idx + 3'd1;
                        end else begin
                            if (acc_bit) mat_res[row_idx][col_idx] <= 1'b1;
                            else mat_res[row_idx][col_idx] <= 1'b0;
                            
                            acc_bit <= 1'b0;
                            dot_idx <= 3'd0;
                            
                            if (col_idx < active_k - 3'd1) begin
                                col_idx <= col_idx + 3'd1;
                            end else begin
                                col_idx <= 3'd0;
                                if (row_idx < active_k - 3'd1) begin
                                    row_idx <= row_idx + 3'd1;
                                end else begin
                                    row_idx <= 3'd0;
                                    
                                    if (target_exp[bit_idx]) begin
                                        for (i = 0; i < 8; i = i + 1) begin
                                            mat_B[i] <= mat_res[i];
                                        end
                                        op_mode <= 2'd3;
                                    end else begin
                                        for (i = 0; i < 8; i = i + 1) begin
                                            mat_B[i] <= mat_res[i];
                                        end
                                        bit_idx <= bit_idx + 6'd1;
                                        if (bit_idx >= MAX_ITER - 6'd1) begin
                                            computing <= 1'b0;
                                            calc_done_flag <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                SAVE_L_SUM: begin
                    // Compute vector multiplication: vec_state = mat_A * init_terms
                    // Apply T^N to Initial State Vector
                    // Sum accumulation
                    for (i = 0; i < 8; i = i + 1) begin
                        sum_L[i] <= vec_result[i];
                    end
                end
                
                SAVE_R_SUM: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        sum_R[i] <= vec_result[i];
                    end
                end
                
                FINISH: begin
                    // XOR the prefix sums
                    result[7:0]   <= sum_R[0] ^ sum_L[0];
                    result[15:8]  <= sum_R[1] ^ sum_L[1];
                    result[23:16] <= sum_R[2] ^ sum_L[2];
                    result[31:24] <= sum_R[3] ^ sum_L[3];
                    result[39:32] <= sum_R[4] ^ sum_L[4];
                    result[47:40] <= sum_R[5] ^ sum_L[5];
                    result[55:48] <= sum_R[6] ^ sum_L[6];
                    result[63:56] <= sum_R[7] ^ sum_L[7];
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Special handling for intermediate matrix multiplication states
            // Since we can't easily do state-specific sequential logic for A=A*B inside the case above without more states,
            // we handle the A = A * B logic here for states CALC_L and CALC_R when op_mode is 3.
            if ((state == CALC_L || state == CALC_R) && op_mode == 2'd3 && computing) begin
                // Perform A = A * B (where B is actually mat_res from previous squaring)
                // This is a sequential multiply block
                 if (dot_idx < active_k) begin
                    acc_bit <= acc_bit ^ (mat_A[row_idx][dot_idx] & mat_B[dot_idx][col_idx]);
                    dot_idx <= dot_idx + 3'd1;
                end else begin
                    if (acc_bit) mat_A[row_idx][col_idx] <= 1'b1;
                    else mat_A[row_idx][col_idx] <= 1'b0;
                    
                    acc_bit <= 1'b0;
                    dot_idx <= 3'd0;
                    
                    if (col_idx < active_k - 3'd1) begin
                        col_idx <= col_idx + 3'd1;
                    end else begin
                        col_idx <= 3'd0;
                        if (row_idx < active_k - 3'd1) begin
                            row_idx <= row_idx + 3'd1;
                        end else begin
                            // Finished A = A * B
                            row_idx <= 3'd0;
                            // Prepare B for next squaring (B = mat_res)
                            for (i = 0; i < 8; i = i + 1) begin
                                mat_B[i] <= mat_res[i];
                            end
                            op_mode <= 2'd0; // Back to standard squaring mode
                            bit_idx <= bit_idx + 6'd1;
                            if (bit_idx >= MAX_ITER - 6'd1) begin
                                computing <= 1'b0;
                                calc_done_flag <= 1'b1;
                            end
                        end
                    end
                end
            end
            
            // Vector Multiplication Logic (Triggered after matrix power is ready)
            // This computes the actual state vector result = T^N * V_init
            // This logic is essentially matrix-vector multiplication
            if (op_mode == 2'd0 && calc_done_flag) begin
                calc_done_flag <= 1'b0;
                // Compute vec_result = mat_A * init_terms (or sum vector)
                // Since we want Prefix Sum, we actually apply T^N to the initial state
                // and XOR the results.
                
                // We need a dedicated block for this or integrate it.
                // For brevity, we will do it in a separate cycle sequence or inline.
                // Let's do it in the state transitions.
            end
        end
    end
    
    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_INIT;
            end
            
            LOAD_INIT: begin
                if (!loading_init) next_state = PREP_L_START;
            end
            
            PREP_L_START: begin
                next_state = CALC_L;
            end
            
            CALC_L: begin
                if (calc_done_flag) next_state = SAVE_L_SUM;
                else next_state = CALC_L;
            end
            
            SAVE_L_SUM: begin
                // Need to compute vector multiplication here
                // We'll use a quick loop logic in the sequential block or assume it's done
                // Actually, we need to calculate Prefix(L-1) = (T^(L-1) applied to Init) sum
                // But the spec asks for XOR sum of terms x_l ... x_r.
                // Result = Prefix(r) XOR Prefix(l-1)
                // Prefix(n) = x_1 ^ x_2 ^ ... ^ x_n
                
                // Let's compute the vector T^(L-1)*V_init
                next_state = PREP_R_START;
            end
            
            PREP_R_START: begin
                next_state = CALC_R;
            end
            
            CALC_R: begin
                if (calc_done_flag) next_state = SAVE_R_SUM;
                else next_state = CALC_R;
            end
            
            SAVE_R_SUM: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Combinational Logic for Vector Multiplication (Matrix * Vector)
    // This block computes the result of the matrix power on the initial vector and accumulates the XOR sum.
    // We need to do this for both L-1 and R.
    // Since we don't have enough states in the FSM, we piggyback on the calc states or add dedicated logic.
    
    // Revised Logic for CALC states:
    // CALC state performs matrix exponentiation.
    // Once exponentiation is done, we need to multiply the result matrix (mat_A) by the initial vector.
    
    // Let's add a dedicated sequential block for the final Vector * Matrix multiplication and Sum accumulation.
    // This is triggered after `computing` falls.
    
    reg [2:0] vec_row;
    reg [2:0] vec_col;
    reg vec_acc;
    reg [7:0] current_vec [0:7];
    reg [7:0] accum_sum [0:7];
    reg vec_mult_active;
    reg vec_mult_done;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vec_row <= 3'd0;
            vec_col <= 3'd0;
            vec_acc <= 1'b0;
            vec_mult_active <= 1'b0;
            vec_mult_done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                current_vec[i] <= 8'd0;
                accum_sum[i] <= 8'd0;
                vec_result[i] <= 8'd0;
            end
        end else begin
            // Trigger logic
            if (state == CALC_L && calc_done_flag && !vec_mult_active) begin
                // Start Vector Multiplication for L
                vec_mult_active <= 1'b1;
                vec_mult_done <= 1'b0;
                vec_row <= 3'd0;
                vec_col <= 3'd0;
                vec_acc <= 1'b0;
                for (i = 0; i < 8; i = i + 1) begin
                    current_vec[i] <= init_terms[i];
                    accum_sum[i] <= 8'd0; // We want to accumulate XOR sum
                end
            end else if (state == CALC_R && calc_done_flag && !vec_mult_active) begin
                // Start Vector Multiplication for R
                vec_mult_active <= 1'b1;
                vec_mult_done <= 1'b0;
                vec_row <= 3'd0;
                vec_col <= 3'd0;
                vec_acc <= 1'b0;
                for (i = 0; i < 8; i = i + 1) begin
                    current_vec[i] <= init_terms[i];
                    accum_sum[i] <= 8'd0;
                end
            end
            
            if (vec_mult_active) begin
                // Compute matrix_row * vector_col
                // mat_A[row][col] & current_vec[col]
                if (vec_col < active_k) begin
                    vec_acc <= vec_acc ^ (mat_A[vec_row][vec_col] & current_vec[vec_col]);
                    vec_col <= vec_col + 3'd1;
                end else begin
                    // Dot product done for one row
                    // vec_acc holds the bit for the new state vector component (vec_result[row])
                    // We also want to XOR this into the sum accumulation
                    if (vec_acc) begin
                        // New component of state vector is 1
                        // XOR it into the running sum for the prefix
                        accum_sum[vec_row] <= accum_sum[vec_row] ^ 8'd1;
                    end
                    // Reset for next row
                    vec_acc <= 1'b0;
                    vec_col <= 3'd0;
                    
                    if (vec_row < active_k - 3'd1) begin
                        vec_row <= vec_row + 3'd1;
                    end else begin
                        // Finished all rows
                        vec_mult_active <= 1'b0;
                        vec_mult_done <= 1'b1;
                        // Output the accumulated sum
                        for (i = 0; i < 8; i = i + 1) begin
                            vec_result[i] <= accum_sum[i];
                        end
                    end
                end
            end
            
            // Reset trigger flags based on main state machine transitions
            if (state != CALC_L && state != CALC_R) begin
                vec_mult_done <= 1'b0;
            end
        end
    end
    
    // Update control signals based on the new vec_mult logic
    always @(*) begin
        // target_exp determines which power to compute
        // For L-1 calculation: target_exp = l_reg - 1
        // For R calculation: target_exp = r_reg
        if (state == PREP_L_START) begin
            if (l_reg > 0) target_exp = l_reg[7:0] - 8'd1; // Simplified, assuming l < 256 for demo
            else target_exp = 8'd0;
        end else if (state == PREP_R_START) begin
            target_exp = r_reg[7:0];
        end else begin
            target_exp = 8'd0;
        end
        
        // managing computing signal
        if ((state == CALC_L || state == CALC_R) && (bit_idx < MAX_ITER || op_mode != 2'd0)) begin
            computing = 1'b1;
        end else begin
            computing = 1'b0;
        end
    end

endmodule