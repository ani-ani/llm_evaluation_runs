module convex_scoring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire [15:0] points_x [0:15],
    input wire [15:0] points_y [0:15],
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter MOD = 32'd998244353;
    parameter MAX_N = 16;

    // State Encoding
    localparam IDLE             = 6'b000001;
    localparam INIT_POWER       = 6'b000010;
    localparam FIND_LINES_SETUP = 6'b000100;
    localparam FIND_LINES_LOOP  = 6'b001000;
    localparam COUNT_COLLINEAR  = 6'b010000;
    localparam UPDATE_RESULT    = 6'b100000;

    // Registers & Internal Storage
    reg [5:0] current_state, next_state;
    
    // Iterator registers
    reg [3:0] i_ptr;           // Outer loop index i
    reg [3:0] j_ptr;           // Inner loop index j
    reg [3:0] k_ptr;           // Point check index k
    
    // Computation registers
    reg [31:0] power_of_two;   // Holds 2^N or powers for subtraction
    reg [31:0] temp_result;    // Accumulator for result
    reg [31:0] sub_val;        // Value to subtract (2^M - M - 1)
    reg [31:0] sub_acc;        // Accumulator for subtraction part
    
    // Line checking registers
    reg signed [15:0] dx_ref;
    reg signed [15:0] dy_ref;
    reg signed [15:0] dx_curr;
    reg signed [15:0] dy_curr;
    reg signed [31:0] cross_prod_1;
    reg signed [31:0] cross_prod_2;
    reg [3:0] collinear_count;
    
    // Flags
    reg line_found_flag;       // Indicates current i,j pair is valid start of a line
    reg [MAX_N-1:0] used_points; // Bitmask to mark points already part of a counted line
    reg [MAX_N-1:0] line_points; // Bitmask for points on current line

    // --- State Transition Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // --- Next State Logic ---
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT_POWER;
                else next_state = IDLE;
            end
            INIT_POWER: begin
                // Wait for power calculation (sequential logic handles the loop)
                if (power_of_two >= (1 << N)) next_state = FIND_LINES_SETUP;
                else next_state = INIT_POWER;
            end
            FIND_LINES_SETUP: begin
                // Initialize loop
                next_state = FIND_LINES_LOOP;
            end
            FIND_LINES_LOOP: begin
                // Iterate i and j
                if (i_ptr >= N) begin
                    next_state = UPDATE_RESULT; // All lines processed
                end else if (j_ptr >= N) begin
                    next_state = FIND_LINES_LOOP; // Need to increment i
                end else if (used_points[i_ptr]) begin
                    next_state = FIND_LINES_LOOP; // Skip used i
                end else if (used_points[j_ptr]) begin
                    next_state = FIND_LINES_LOOP; // Skip used j (wait for next j)
                end else begin
                   _state = COUNT_COLLINEAR; // Found candidate pair
                end
            end
            COUNT_COLLINEAR: begin
                // Check all k
                if (k_ptr >= N) begin
                    if (collinear_count >= 2) next_state = FIND_LINES_SETUP; // Mark and restart search
                    else next_state = FIND_LINES_LOOP; // No line found, continue
                end else begin
                    next_state = COUNT_COLLINEAR; // Continue loop
                end
            end
            UPDATE_RESULT: begin
                // Final calculation
                next_state = DONE; // We will add a DONE state implicitly or loop back to IDLE
            end
            default: next_state = IDLE;
        endcase
    end

    // --- Datapath Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            power_of_two <= 1;
            sub_acc <= 0;
            i_ptr <= 0;
            j_ptr <= 1;
            k_ptr <= 0;
            used_points <= 0;
            line_points <= 0;
            line_found_flag <= 0;
            collinear_count <= 0;
            sub_val <= 0;
        end else begin
            done <= 0;
            
            case (current_state)
                IDLE: begin
                    // Reset accumulators
                    result <= 0;
                    sub_acc <= 0;
                    power_of_two <= 1;
                    i_ptr <= 0;
                    j_ptr <= 1;
                    k_ptr <= 0;
                    used_points <= 0;
                    line_points <= 0;
                    sub_val <= 0;
                end

                INIT_POWER: begin
                    // Calculate 2^N
                    if (power_of_two < (1 << N)) begin
                        power_of_two <= power_of_two << 1;
                    end
                end

                FIND_LINES_SETUP: begin
                    // Reset sub-val accumulator if we just finished power calc
                    if (power_of_two == (1 << N)) begin
                        // Initialize result = 2^N - 1 - N
                        // We use power_of_two which is 2^N. 
                        // 2^N - 1 - N = power_of_two - 1 - N
                        result <= (power_of_two - 1 - N) % MOD;
                        sub_acc <= 0;
                    end
                    
                    // Reset pointers for search
                    // Find first unused i
                    i_ptr <= 0;
                    while (i_ptr < N && used_points[i_ptr]) i_ptr <= i_ptr + 1;
                    
                    // We need a robust way to handle the loops in HW.
                    // We will handle increments in the LOOP state or dedicated logic.
                end

                FIND_LINES_LOOP: begin
                    // Logic to increment pointers
                    // Case 1: i_ptr >= N -> Done
                    if (i_ptr >= N) begin
                        // Do nothing, wait for state transition
                    end else begin
                        // Check if we need to increment j
                        if (j_ptr >= N) begin
                            // Advance i to next unused
                            i_ptr <= i_ptr + 1;
                            // Reset j logic needs to happen after i updates in next cycle or handled here? 
                            // Better: Increment i, and set j = i+1 in next cycle.
                        end else if (used_points[j_ptr]) begin
                            j_ptr <= j_ptr + 1;
                        end else if (used_points[i_ptr]) begin
                            // i became used (should not happen in this flow but safe)
                            i_ptr <= i_ptr + 1;
                        end else begin
                            // We are ready to check line (i, j) only if we are in COUNT_COLLINEAR state
                            // But this state is used to setup the check.
                            // Actually, the transition logic handles the 'if' check.
                            // We just need to manage j_ptr incrementing if invalid.
                            if (used_points[j_ptr]) j_ptr <= j_ptr + 1;
                        end
                        
                        // Specific Logic: If we detected (in next_state logic) that current (i,j) is used or j out of bounds:
                        // We handle auto-increment here to avoid combinational loop in next_state.
                        
                        // Reset line specific counters
                        line_points <= 0;
                        collinear_count <= 0;
                        k_ptr <= 0;
                        
                        // If current i and j are valid (checked in next_state logic), prepare reference
                        if (!used_points[i_ptr] && !used_points[j_ptr] && j_ptr < N) begin
                            dx_ref <= points_x[j_ptr] - points_x[i_ptr];
                            dy_ref <= points_y[j_ptr] - points_y[i_ptr];
                            line_points <= (1 << i_ptr) | (1 << j_ptr);
                            collinear_count <= 2;
                        end
                    end
                    
                    // Handle loop increment mechanics manually here for robustness:
                    // If in FIND_LINES_LOOP and next_state decided we are skipping:
                    if (next_state == FIND_LINES_LOOP) begin
                        if (j_ptr >= N) begin
                            // Move to next i
                            i_ptr <= i_ptr + 1;
                            j_ptr <= i_ptr + 2; // i+1 is used by i_ptr check, so i+2
                            if (i_ptr + 1 < N && !used_points[i_ptr+1]) begin
                                // Setup for next i
                            end
                        end else if (used_points[j_ptr]) begin
                            j_ptr <= j_ptr + 1;
                        end else if (used_points[i_ptr]) begin
                            i_ptr <= i_ptr + 1;
                            j_ptr <= i_ptr + 2;
                        end
                    end
                end

                COUNT_COLLINEAR: begin
                    // Check point k_ptr
                    if (k_ptr < N) begin
                        // Skip if k is i or j or already on line (safety) or used
                        if (k_ptr != i_ptr && k_ptr != j_ptr && !used_points[k_ptr]) begin
                            // Calculate vectors
                            dx_curr <= points_x[k_ptr] - points_x[i_ptr];
                            dy_curr <= points_y[k_ptr] - points_y[i_ptr];
                            
                            // Check collinear: dx_ref * dy_curr == dy_ref * dx_curr
                            cross_prod_1 <= dx_ref * (points_y[k_ptr] - points_y[i_ptr]);
                            cross_prod_2 <= dy_ref * (points_x[k_ptr] - points_x[i_ptr]);
                            
                            // We need a 1-cycle delay for multiplication result availability if we do it in combinational logic block
                            // But here we are in a sequential block. We can't do the check immediately if multiplication is used.
                            // However, we can just do the calculation for the *next* k in the next cycle.
                            // Let's perform the check using registered values from previous k cycle.
                            
                            // Correct approach for this block:
                            // 1. Use values calculated in previous cycle
                            // 2. Add to count/mask
                            // 3. Calculate new values for current k
                            // 4. Increment k
                        end
                        
                        // Move to next k
                        k_ptr <= k_ptr + 1;
                    end
                end
                
                UPDATE_RESULT: begin
                    // Finalize result
                    // result = result - (sub_acc)
                    result <= (result - sub_acc + MOD) % MOD;
                    done <= 1;
                    // Return to IDLE implicitly or stay here until reset
                    // Let's stay here or transition to IDLE. The state machine loop will go to DONE (default to IDLE)
                    // So we set a flag to go to IDLE.
                end
                
                default: begin
                    // Done state handled by 'done' signal
                    if (done) begin
                        // Wait for reset
                    end
                end
            endcase
        end
    end
    
    // --- Combinational Helper Logic for Counting and Updating ---
    // Because complex arithmetic and loops are hard in a single always block, 
    // we use a separate combinational block to handle the 'counting' result
    // and the pointer updates that depend on state.
    
    // To strictly follow the single always block requirement for synthesis, 
    // we need to break the logic carefully.
    
    // Re-implementing the critical logic in the sequential block properly:
    // The code above is a sketch. Let's make it robust.
    
    // Refinement: The COUNT_COLLINEAR state needs to be a loop.
    // We will register the cross product results.
    
    // Registers for collision detection
    reg is_collinear;
    always @(posedge clk) begin
        if (current_state == COUNT_COLLINEAR) begin
            is_collinear <= (cross_prod_1 == cross_prod_2);
        end
    end

    // --- Corrected Sequential Logic ---
    // Merging logic to ensure proper sequence
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            power_of_two <= 1;
            sub_acc <= 0;
            i_ptr <= 0;
            j_ptr <= 1;
            k_ptr <= 0;
            used_points <= 0;
            line_points <= 0;
            state_reg <= IDLE;
        end else begin
            case (state_reg)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        power_of_two <= 1;
                        sub_acc <= 0;
                        used_points <= 0;
                        i_ptr <= 0;
                        j_ptr <= 1;
                        state_reg <= CALC_POWER;
                    end
                end

                CALC_POWER: begin
                    if (power_of_two < (1 << N)) begin
                        power_of_two <= power_of_two << 1;
                    end else begin
                        // Initialize result: 2^N - 1 - N
                        result <= (power_of_two - 1 - N) % MOD;
                        state_reg <= SEARCH_START;
                    end
                end

                SEARCH_START: begin
                    // Reset loop vars
                    i_ptr <= 0;
                    j_ptr <= 1;
                    state_reg <= SEARCH_LOOP;
                end

                SEARCH_LOOP: begin
                    // 1. Find next valid i
                    if (i_ptr >= N) begin
                        state_reg <= FINALIZE;
                    end else if (used_points[i_ptr]) begin
                        i_ptr <= i_ptr + 1;
                        j_ptr <= i_ptr + 2;
                    end else if (j_ptr >= N) begin
                        i_ptr <= i_ptr + 1;
                        j_ptr <= i_ptr + 1;
                    end else if (used_points[j_ptr]) begin
                        j_ptr <= j_ptr + 1;
                    end else begin
                        // Valid (i, j) found
                        // Setup for line count
                        line_points <= (1 << i_ptr) | (1 << j_ptr);
                        k_ptr <= 0;
                        
                        // Calculate reference vector
                        dx_ref <= points_x[j_ptr] - points_x[i_ptr];
                        dy_ref <= points_y[j_ptr] - points_y[i_ptr];
                        
                        state_reg <= COUNT_LOOP;
                    end
                end

                COUNT_LOOP: begin
                    if (k_ptr >= N) begin
                        // Finished counting for this line
                        // Check size
                        if (collinear_count >= 3) begin // >= 3 because 2 points is not a polygon subset (2^2 - 2 - 1 = 1, but 2 points form a line, not polygon, usually 3+ is needed for area, but formula says k>=2. Wait, 2^k - k - 1. For k=2, it's 4-2-1=1. So we must subtract for pairs too.)
                            // Actually, we need to count the line size M.
                            // If M=2, 2^2 - 2 - 1 = 1. So we subtract 1.
                            // But the prompt says "Subtract subsets that do NOT form convex polygons".
                            // Collinear subsets of size k >= 2. So M must be >= 2.
                            
                            // We need to calculate 2^M - M - 1.
                            // We can reuse power_of_two or calculate new.
                            // Let's calculate 2^M.
                            
                            // Update used_points
                            used_points <= used_points | line_points;
                            
                            // Calculate subtraction value 2^M - M - 1
                            // We need to compute 2^M. Since M <= 16, we can just shift.
                            // We'll store 2^M in a temp variable.
                            // To do this efficiently, we can enter a sub-state or just use logic.
                            // Since we are in state machine, let's use a helper state.
                            sub_val <= (1 << collinear_count) - collinear_count - 1;
                            
                            state_reg <= ACCUMULATE;
                        end else begin
                            // M < 3 (actually M=2 is valid to subtract per formula, but let's check prompt logic).
                            // Prompt: "Subtract (2^k - k - 1) for every collinear subset of size k >= 2."
                            // If M=2, we subtract 1. 
                            // So we should trigger ACCUMULATE if collinear_count >= 2.
                            // But wait, for M=2, it's just a pair. Are we counting pairs?
                            // "sum of scores of all convex polygons formed by a subset of points."
                            // Total score = 2^N - 1 (exclude empty).
                            // Subtract N (single points).
                            // Subtract (2^k - k - 1) for collinear k >= 2.
                            // So M=2 is included.
                            
                            // However, if we subtract for M=2 (line of 2 points), we subtract 1.
                            // But we are iterating over pairs. If we have N points on a line, 
                            // we have 1 line of size N.
                            // We should NOT subtract for each pair (i,j) of that line.
                            // We should find the maximal line.
                            
                            // My current logic finds a line defined by (i, j) and counts all points on it.
                            // So if we find M >= 2, we subtract (2^M - M - 1) ONCE for that set.
                            // Then mark all points in that set as used.
                            
                            if (collinear_count >= 2) begin
                                used_points <= used_points | line_points;
                                sub_val <= (1 << collinear_count) - collinear_count - 1;
                                state_reg <= ACCUMULATE;
                            end else begin
                                // Should not happen (at least i and j are in line_points)
                                state_reg <= SEARCH_LOOP;
                            end
                        end
                        
                        // Increment i/j pointers is handled in SEARCH_LOOP setup
                        // We need to advance the loop counter here
                        // If we mark points as used, we must break the search loop.
                        // We'll set i_ptr and j_ptr to force restart of search in SEARCH_LOOP.
                        i_ptr <= 0;
                        j_ptr <= 1;
                        
                    end else begin
                        // Check k_ptr
                        if (k_ptr == i_ptr || k_ptr == j_ptr || used_points[k_ptr]) begin
                            // Skip
                            k_ptr <= k_ptr + 1;
                        end else begin
                            // Check collinearity: (x_j - x_i)(y_k - y_i) == (y_j - y_i)(x_k - x_i)
                            // Calculate cross products
                            cross_prod_1 <= dx_ref * (points_y[k_ptr] - points_y[i_ptr]);
                            cross_prod_2 <= dy_ref * (points_x[k_ptr] - points_x[i_ptr]);
                            
                            // We need to wait 1 cycle for multiplication result if combinational.
                            // Or we can assume multiplication takes 1 cycle.
                            // Let's use the 'CHECK_RESULT' state to handle the logic after multiplication.
                            state_reg <= CHECK_RESULT;
                        end
                    end
                end

                CHECK_RESULT: begin
                    // Multiplication result is ready (from previous cycle logic in COUNT_LOOP, 
                    // actually the assignments happened in COUNT_LOOP, so here they are ready if we registered them.
                    // Wait, in COUNT_LOOP we assign `cross_prod_1 <= ...`. 
                    // These assignments take effect at the end of the cycle. So in CHECK_RESULT (next cycle), they are valid.
                    
                    if (cross_prod_1 == cross_prod_2) begin
                        // It is collinear
                        line_points <= line_points | (1 << k_ptr);
                        collinear_count <= collinear_count + 1;
                    end
                    k_ptr <= k_ptr + 1;
                    state_reg <= COUNT_LOOP;
                end

                ACCUMULATE: begin
                    // Subtract sub_val from result modulo MOD
                    result <= (result - sub_val + MOD) % MOD;
                    state_reg <= SEARCH_LOOP;
                end

                FINALIZE: begin
                    // Result is ready
                    done <= 1;
                    state_reg <= IDLE; // Auto reset to IDLE after done? Or stay?
                    // Requirement: "output reg done // High when computation is done"
                    // Typically stays high until reset or new start.
                    state_reg <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    // Hold done high
                    // Stay here until reset
                end

            endcase
        end
    end

endmodule
