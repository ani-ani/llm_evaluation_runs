module prime_minister_happiness(
    input clk,
    input rst_n,
    input start,
    input [5:0] N,
    input [5:0] K,
    input [31:0] x [0:11],
    input [31:0] y [0:11],
    input [31:0] residents [0:11],
    output reg [31:0] min_D,
    output reg done
);

    // --- State Definitions ---
    localparam IDLE = 3'b000;
    localparam PRECOMP_DIST = 3'b001;
    localparam SORT_DIST = 3'b010;
    localparam CHECK_THRESHOLD = 3'b011;
    localparam DONE_SQRT = 3'b100;

    reg [2:0] state;
    reg [2:0] sub_state;

    // --- Registers for Input Storage ---
    reg [5:0] N_reg;
    reg [5:0] K_reg;
    reg [31:0] x_reg [0:11];
    reg [31:0] y_reg [0:11];
    reg [31:0] residents_reg [0:11];

    // --- Registers for Algorithms ---
    // Distance Matrix (Squared). 12x12. 64-bit to hold square of 32-bit diff.
    reg [63:0] dist_sq [0:11][0:11];
    
    // Unique Distances List
    reg [63:0] unique_dists [0:65];
    reg [6:0] dist_count;
    reg [63:0] temp_dist; // For swapping

    // Iteration Indices
    reg [5:0] i, j, k, m;
    reg [6:0] loop_idx; // Used for iterating unique distances
    
    // --- Specific Algorithm Registers ---
    // Precomp
    reg [31:0] diff_x, diff_y;
    reg [63:0] calc_dist_sq_temp;
    
    // BFS / Components
    reg [11:0] visited_mask;
    reg [11:0] current_component_mask;
    reg [11:0] queue [0:11];
    reg [5:0] queue_head;
    reg [5:0] queue_tail;
    reg [5:0] u; // Current node in BFS
    
    // Subset Sum DP
    reg [29:0] dp_mask;
    wire [29:0] mask_k = (K_reg == 0) ? 30'h3FFFFFFF : ((1 << K_reg) - 1);
    wire [5:0] rem_dp = residents_reg[k] % K_reg;
    // Cyclic shift left by rem_dp
    wire [29:0] dp_rotated = ((dp_mask << rem_dp) | (dp_mask >> (K_reg - rem_dp))) & mask_k;
    
    // Threshold Check
    reg [63:0] current_threshold;
    reg [63:0] best_threshold;
    reg valid_found;
    reg component_has_solution;

    // Sqrt Registers
    reg [31:0] sq_root;
    reg [63:0] sq_val;
    reg [31:0] sq_bit;
    reg [31:0] let_t;
    reg [63:0] sq_temp;

    // --- Main FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_D <= 0;
            dist_count <= 0;
            valid_found <= 0;
            best_threshold <= 0;
            current_threshold <= 0;
            sub_state <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        N_reg <= N;
                        K_reg <= K;
                        // Copy arrays
                        x_reg[0] <= x[0]; x_reg[1] <= x[1]; x_reg[2] <= x[2]; x_reg[3] <= x[3];
                        x_reg[4] <= x[4]; x_reg[5] <= x[5]; x_reg[6] <= x[6]; x_reg[7] <= x[7];
                        x_reg[8] <= x[8]; x_reg[9] <= x[9]; x_reg[10] <= x[10]; x_reg[11] <= x[11];
                        y_reg[0] <= y[0]; y_reg[1] <= y[1]; y_reg[2] <= y[2]; y_reg[3] <= y[3];
                        y_reg[4] <= y[4]; y_reg[5] <= y[5]; y_reg[6] <= y[6]; y_reg[7] <= y[7];
                        y_reg[8] <= y[8]; y_reg[9] <= y[9]; y_reg[10] <= y[10]; y_reg[11] <= y[11];
                        residents_reg[0] <= residents[0]; residents_reg[1] <= residents[1]; residents_reg[2] <= residents[2]; residents_reg[3] <= residents[3];
                        residents_reg[4] <= residents[4]; residents_reg[5] <= residents[5]; residents_reg[6] <= residents[6]; residents_reg[7] <= residents[7];
                        residents_reg[8] <= residents[8]; residents_reg[9] <= residents[9]; residents_reg[10] <= residents[10]; residents_reg[11] <= residents[11];
                        
                        state <= PRECOMP_DIST;
                        i <= 0;
                        j <= 0;
                        dist_count <= 0;
                        sub_state <= 0;
                    end
                end

                PRECOMP_DIST: begin
                    // State to compute all pairwise distances
                    // sub_state 0: Setup diff calculation
                    // sub_state 1: Store result and advance indices
                    if (i < N_reg) begin
                        if (j < N_reg) begin
                            if (sub_state == 0) begin
                                if (i != j) begin
                                    // Compute diffs (handling unsigned coords)
                                    if (x_reg[i] >= x_reg[j]) diff_x <= x_reg[i] - x_reg[j]; else diff_x <= x_reg[j] - x_reg[i];
                                    if (y_reg[i] >= y_reg[j]) diff_y <= y_reg[i] - y_reg[j]; else diff_y <= y_reg[j] - y_reg[i];
                                    sub_state <= 1;
                                end else begin
                                    dist_sq[i][j] <= 0;
                                    j <= j + 1;
                                end
                            end else begin // sub_state == 1
                                // Compute square and store
                                dist_sq[i][j] <= (diff_x * diff_x) + (diff_y * diff_y);
                                j <= j + 1;
                                sub_state <= 0;
                            end
                        end else begin
                            j <= 0;
                            i <= i + 1;
                            sub_state <= 0;
                        end
                    end else begin
                        state <= SORT_DIST;
                        i <= 1; // Start sorting
                        j <= 0;
                        dist_count <= 0;
                        sub_state <= 0; // 0: Build unique list, 1: Sort
                    end
                end

                SORT_DIST: begin
                    // Sorting involves two phases: Extraction and Bubble Sort
                    if (sub_state == 0) begin
                        // Extract unique distances from dist_sq matrix
                        // We iterate i=0..N-1, j=i+1..N-1 to get upper triangle
                        // But we need to store them in unique_dists array
                        // Let's use i and j for loops, k for checking duplicates
                        if (i < N_reg) begin
                            if (j < N_reg) begin
                                // Check if dist_sq[i][j] is already in unique_dists
                                if (k < dist_count) begin
                                    if (unique_dists[k] == dist_sq[i][j]) begin
                                        k <= dist_count; // Mark as found (skip adding)
                                    end else begin
                                        k <= k + 1;
                                    end
                                end else begin
                                    // Not found, add it
                                    unique_dists[dist_count] <= dist_sq[i][j];
                                    dist_count <= dist_count + 1;
                                    k <= 0;
                                    j <= j + 1;
                                end
                            end else begin
                                j <= i + 1;
                                i <= i + 1;
                                k <= 0;
                            end
                        end else begin
                            // Done extracting, switch to sort phase
                            sub_state <= 1;
                            i <= 0; // For bubble sort
                            j <= 0;
                        end
                    end else if (sub_state == 1) begin
                        // Bubble Sort
                        if (dist_count > 1) begin
                            if (i < dist_count - 1) begin
                                if (j < dist_count - i - 1) begin
                                    if (unique_dists[j] > unique_dists[j+1]) begin
                                        temp_dist <= unique_dists[j];
                                        unique_dists[j] <= unique_dists[j+1];
                                        unique_dists[j+1] <= temp_dist;
                                    end
                                    j <= j + 1;
                                end else begin
                                    j <= 0;
                                    i <= i + 1;
                                end
                            end else begin
                                // Done sorting
                                // Check for trivial case N=1
                                if (N_reg <= 1) begin
                                    state <= DONE_SQRT;
                                    sub_state <= 0;
                                end else begin
                                    state <= CHECK_THRESHOLD;
                                    sub_state <= 0;
                                    loop_idx <= 0;
                                    current_threshold <= unique_dists[0];
                                    best_threshold <= 64'hFFFF_FFFF_FFFF_FFFF;
                                    valid_found <= 0;
                                end
                            end
                        end else begin
                            // 0 or 1 distance
                            if (N_reg <= 1) state <= DONE_SQRT;
                            else begin
                                current_threshold <= unique_dists[0];
                                state <= CHECK_THRESHOLD;
                                sub_state <= 0;
                                loop_idx <= 0;
                            end
                        end
                    end
                end

                CHECK_THRESHOLD: begin
                    // Main Algorithm Loop
                    // sub_state 0: Init check for current_threshold
                    // sub_state 1: Component Discovery Loop
                    // sub_state 2: BFS (Queue not empty)
                    // sub_state 3: Process Neighbors
                    // sub_state 4: Subset Sum DP
                    // sub_state 5: Next Threshold

                    case (sub_state)
                        0: begin
                            // Reset for checking this threshold
                            visited_mask <= 0;
                            component_has_solution <= 0;
                            i <= 0; // Node iterator
                            sub_state <= 1;
                        end

                        1: begin
                            // Find first unvisited node for new component
                            if (i < N_reg) begin
                                if ((visited_mask >> i) & 1'b0) begin
                                    // New component found
                                    current_component_mask <= (1'b1 << i);
                                    visited_mask <= visited_mask | (1'b1 << i);
                                    queue[0] <= i;
                                    queue_head <= 0;
                                    queue_tail <= 1;
                                    sub_state <= 2; // Go to BFS expansion
                                end else begin
                                    i <= i + 1;
                                end
                            end else begin
                                // All nodes visited. Check result.
                                if (component_has_solution) begin
                                    best_threshold <= current_threshold;
                                    valid_found <= 1;
                                    state <= DONE_SQRT; // We found the minimal valid D
                                    sub_state <= 0;
                                end else begin
                                    // Try next threshold
                                    if (loop_idx < dist_count - 1) begin
                                        loop_idx <= loop_idx + 1;
                                        current_threshold <= unique_dists[loop_idx + 1];
                                        sub_state <= 0; // Reset check
                                    end else begin
                                        // No valid distance found (should not happen if D=0 works)
                                        // If valid_found is false, return 0 or error? Assume 0 if possible.
                                        // But we check all. If no solution, maybe return 0 or best.
                                        // Let's just output best_threshold (likely 0 if valid, else 0)
                                        // Or if valid_found never set, we might be here.
                                        // If we are here, and valid_found is false, then no subset sum found at all.
                                        // Return 0.
                                        state <= DONE_SQRT;
                                        sub_state <= 0;
                                        if (!valid_found) best_threshold <= 0;
                                    end
                                end
                            end
                        end

                        2: begin
                            // BFS: Check queue
                            if (queue_head < queue_tail) begin
                                u <= queue[queue_head];
                                queue_head <= queue_head + 1;
                                m <= 0; // Neighbor index
                                sub_state <= 3;
                            end else begin
                                // Queue empty, Component extracted. Check Subset Sum.
                                // Reset DP
                                dp_mask <= 1; // Bit 0 = 1 (Empty set reachable)
                                k <= 0;
                                sub_state <= 4;
                            end
                        end

                        3: begin
                            // BFS: Find neighbors of u
                            if (m < N_reg) begin
                                // Check connectivity: dist_sq[u][m] <= current_threshold
                                // And not visited
                                if (((visited_mask >> m) & 1'b0) && (dist_sq[u][m] <= current_threshold)) begin
                                    visited_mask <= visited_mask | (1'b1 << m);
                                    current_component_mask <= current_component_mask | (1'b1 << m);
                                    queue[queue_tail] <= m;
                                    queue_tail <= queue_tail + 1;
                                end
                                m <= m + 1;
                            end else begin
                                sub_state <= 2; // Back to check queue
                            end
                        end

                        4: begin
                            // Subset Sum DP: Iterate cities in component
                            if (k < N_reg) begin
                                if ((current_component_mask >> k) & 1'b1) begin
                                    // Update DP
                                    // dp_mask = dp_mask | dp_rotated
                                    // This uses combinational wire dp_rotated
                                    dp_mask <= dp_mask | dp_rotated;
                                end
                                k <= k + 1;
                            end else begin
                                // Check if mod 0 is reachable (bit 0)
                                if (dp_mask[0]) component_has_solution <= 1;
                                i <= i + 1; // Next component
                                sub_state <= 1;
                            end
                        end
                    endcase
                end

                DONE_SQRT: begin
                    // Compute Sqrt(best_threshold) * 65536
                    // Algorithm: Bit-by-bit method
                    // sub_state 0: Init
                    // sub_state 1: Loop
                    case (sub_state)
                        0: begin
                            if (valid_found) begin
                                sq_root <= 0;
                                sq_val <= best_threshold;
                                sq_bit <= 32'h80000000; // MSB for 32-bit root
                                sub_state <= 1;
                            end else begin
                                // No solution found or N=0. Output 0.
                                min_D <= 0;
                                done <= 1;
                                state <= IDLE;
                            end
                        end
                        1: begin
                            if (sq_bit != 0) begin
                                let_t <= sq_root | sq_bit;
                                sub_state <= 2;
                            end else begin
                                // Finalize
                                // Convert to Q16.16: sq_root (integer) << 16
                                // sq_root is 32-bit max. shift 16 -> 48 bits. Output is 32 bits.
                                // Truncate upper bits or assume result fits.
                                min_D <= {sq_root[15:0], 16'b0}; // Equivalent to sq_root << 16, keeping 32 bits
                                done <= 1;
                                state <= IDLE;
                            end
                        end
                        2: begin
                            // Compute sq_temp = let_t * let_t
                            sq_temp <= let_t * let_t;
                            sub_state <= 3;
                        end
                        3: begin
                            // Check sq_val >= sq_temp
                            if (sq_val >= sq_temp) begin
                                sq_root <= let_t;
                            end
                            sq_bit <= sq_bit >> 1;
                            sub_state <= 1;
                        end
                    endcase
                end
            endcase
        end
    end

endmodule