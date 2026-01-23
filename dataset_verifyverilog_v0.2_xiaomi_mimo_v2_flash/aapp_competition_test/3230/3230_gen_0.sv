// =============================================================================
// Module: tram_explosion_counter
// Description: Counts explosions in a tram layout based on passenger-seat conflicts.
// Algorithm:
//   1. READ_GRID: Read 100 chars (10x10 grid), store X and L positions.
//   2. CALC_DISTANCES: For each X, find closest L (squared Euclidean distance).
//   3. RESOLVE_CONFLICTS: Count how many Xs target each L and track their distances.
//   4. COUNT_EXPLOSIONS: Check for ties (multiple Xs targeting same L with equal dist).
// Author: ASIC Designer
// Date: 2024
// =============================================================================

module tram_explosion_counter (
    input wire clk,             // Clock signal
    input wire rst_n,           // Active-low reset
    input wire start,           // High to start processing the next frame
    input wire [7:0] char_in,   // ASCII character input
    output reg [7:0] char_addr, // Address to read char_in (0-99)
    output reg [3:0] explosions,// Number of explosions detected
    output reg done             // High when processing is complete
);

    // Parameters
    parameter MAX_X = 8;        // Maximum number of passengers
    parameter MAX_L = 8;        // Maximum number of seats
    parameter GRID_SIZE = 100;  // 10x10 grid
    parameter IDLE = 3'b000;
    parameter READ_GRID = 3'b001;
    parameter CALC_DISTANCES = 3'b010;
    parameter RESOLVE_CONFLICTS = 3'b011;
    parameter COUNT_EXPLOSIONS = 3'b100;
    parameter FINISHED = 3'b101;

    // Internal Registers and Wires
    reg [2:0] state;
    reg [2:0] next_state;
    reg [6:0] load_idx;         // Counter for grid loading (0-99)
    reg [3:0] x_count;          // Number of Xs found
    reg [3:0] l_count;          // Number of Ls found
    
    // Storage for X positions (Row, Col) and L positions (Row, Col)
    reg [3:0] x_row [0:MAX_X-1];
    reg [3:0] x_col [0:MAX_X-1];
    reg [3:0] l_row [0:MAX_L-1];
    reg [3:0] l_col [0:MAX_L-1];
    
    // Storage for closest L index for each X and its distance
    reg [3:0] x_target_l_idx [0:MAX_X-1];
    reg [7:0] x_min_dist [0:MAX_X-1];
    
    // Conflict resolution storage
    reg [7:0] l_min_dist [0:MAX_L-1];       // Minimum distance found for this L
    reg [3:0] l_target_count [0:MAX_L-1];   // How many Xs target this L
    reg       l_has_tie [0:MAX_L-1];        // Flag if multiple Xs have same dist
    
    // Loop indices and counters
    reg [3:0] loop_i;  // Outer loop index (over Xs)
    reg [3:0] loop_j;  // Inner loop index (over Ls)
    reg [3:0] loop_k;  // Final loop index (over Ls)
    
    // Computation registers
    reg signed [4:0] diff_r;
    reg signed [4:0] diff_c;
    reg signed [8:0] dist_sq_calc; // (9*81)*2 approx 1500, fits in 11 bits, but we use 9
    reg [7:0] current_dist;
    reg [3:0] current_target;
    reg min_updated;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Values
            char_addr <= 8'd0;
            explosions <= 4'd0;
            done <= 1'b0;
            load_idx <= 7'd0;
            x_count <= 4'd0;
            l_count <= 4'd0;
            loop_i <= 4'd0;
            loop_j <= 4'd0;
            loop_k <= 4'd0;
            // Clear storage (not strictly necessary if we check counts, but good for safety)
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    explosions <= 4'd0;
                    if (start) begin
                        load_idx <= 7'd0;
                        x_count <= 4'd0;
                        l_count <= 4'd0;
                        // next_state handled in combinational block, but we set internal flags here
                    end
                end

                READ_GRID: begin
                    // Update Address
                    char_addr <= load_idx + 1; // Pre-fetch next char, or keep current
                    if (load_idx < GRID_SIZE) begin
                        // Process current char_in
                        if (char_in == 8'd88) begin // 'X'
                            if (x_count < MAX_X) begin
                                x_row[x_count] <= load_idx / 10; // Division in hardware (synthesis will optimize)
                                x_col[x_count] <= load_idx % 10;
                                x_count <= x_count + 1;
                            end
                        end else if (char_in == 8'd76) begin // 'L'
                            if (l_count < MAX_L) begin
                                l_row[l_count] <= load_idx / 10;
                                l_col[l_count] <= load_idx % 10;
                                l_count <= l_count + 1;
                            end
                        end
                        load_idx <= load_idx + 1;
                    end
                end

                CALC_DISTANCES: begin
                    // Loop through Xs (loop_i) and Ls (loop_j)
                    // Operation happens in combinational block, here we manage indices
                    
                    // Logic:
                    // If we are in this state, we need to iterate.
                    // We will use a single-cycle calculation per pair or pipelined.
                    // Since MAX_X * MAX_L = 64, we can do this in 64 cycles easily.
                    
                    if (loop_i < x_count) begin
                        if (loop_j < l_count) begin
                            // Calculation done in comb logic, update min here
                            if (loop_j == 0) begin
                                // Init min for this X
                                x_min_dist[loop_i] <= current_dist;
                                x_target_l_idx[loop_i] <= current_target;
                            end else begin
                                // Compare
                                if (current_dist < x_min_dist[loop_i]) begin
                                    x_min_dist[loop_i] <= current_dist;
                                    x_target_l_idx[loop_i] <= current_target;
                                end
                            end
                            loop_j <= loop_j + 1;
                        end else begin
                            loop_j <= 0;
                            loop_i <= loop_i + 1;
                        end
                    end
                end

                RESOLVE_CONFLICTS: begin
                    // Iterate loop_k over Xs to populate l_target_count and l_min_dist
                    // Logic: For each X, look at its target L.
                    if (loop_k < x_count) begin
                        // Target L index
                        if (l_target_count[x_target_l_idx[loop_k]] == 0) begin
                            // First visitor
                            l_min_dist[x_target_l_idx[loop_k]] <= x_min_dist[loop_k];
                            l_target_count[x_target_l_idx[loop_k]] <= 1;
                            l_has_tie[x_target_l_idx[loop_k]] <= 0;
                        end else begin
                            // Existing visitor(s)
                            if (x_min_dist[loop_k] == l_min_dist[x_target_l_idx[loop_k]]) begin
                                l_target_count[x_target_l_idx[loop_k]] <= l_target_count[x_target_l_idx[loop_k]] + 1;
                                l_has_tie[x_target_l_idx[loop_k]] <= 1;
                            end else if (x_min_dist[loop_k] < l_min_dist[x_target_l_idx[loop_k]]) begin
                                // New closer visitor, replace
                                l_min_dist[x_target_l_idx[loop_k]] <= x_min_dist[loop_k];
                                l_target_count[x_target_l_idx[loop_k]] <= 1;
                                l_has_tie[x_target_l_idx[loop_k]] <= 0;
                            end
                            // If x_min_dist > l_min_dist, ignore this X (it's fighting a lost cause)
                        end
                        loop_k <= loop_k + 1;
                    end
                end

                COUNT_EXPLOSIONS: begin
                    // Iterate through Ls to count conflicts
                    if (loop_k < l_count) begin
                        if (l_target_count[loop_k] > 1 && l_has_tie[loop_k]) begin
                            explosions <= explosions + 1;
                        end
                        loop_k <= loop_k + 1;
                    end else begin
                        // Done
                        done <= 1'b1;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Logic for Next State and Datapath Calculations
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = READ_GRID;
                else next_state = IDLE;
            end
            
            READ_GRID: begin
                if (load_idx == GRID_SIZE) next_state = CALC_DISTANCES;
                else next_state = READ_GRID;
            end
            
            CALC_DISTANCES: begin
                // Check if loops are done
                // loop_i < x_count means we still have Xs to process
                // loop_j < l_count means we still have Ls for current X
                if (loop_i < x_count) begin
                    next_state = CALC_DISTANCES;
                end else begin
                    next_state = RESOLVE_CONFLICTS;
                end
            end
            
            RESOLVE_CONFLICTS: begin
                if (loop_k < x_count) next_state = RESOLVE_CONFLICTS;
                else next_state = COUNT_EXPLOSIONS;
            end
            
            COUNT_EXPLOSIONS: begin
                if (loop_k < l_count) next_state = COUNT_EXPLOSIONS;
                else next_state = FINISHED;
            end
            
            FINISHED: begin
                next_state = FINISHED; // Stays here until reset
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Distance Calculation Logic (Combinational)
    // Calculates distance between current X (loop_i) and current L (loop_j)
    always @(*) begin
        reg signed [4:0] r_diff, c_diff;
        reg signed [8:0] d_sq;
        
        if (state == CALC_DISTANCES && loop_i < x_count && loop_j < l_count) begin
            // Calculate difference
            r_diff = $signed({1'b0, x_row[loop_i]}) - $signed({1'b0, l_row[loop_j]});
            c_diff = $signed({1'b0, x_col[loop_i]}) - $signed({1'b0, l_col[loop_j]});
            
            // Absolute values
            if (r_diff[4]) r_diff = -r_diff;
            if (c_diff[4]) c_diff = -c_diff;
            
            // Square (ensure non-negative)
            d_sq = (r_diff * r_diff) + (c_diff * c_diff);
            
            current_dist = d_sq[7:0]; // Fits in 8 bits (max 162)
            current_target = loop_j;
        end else begin
            current_dist = 8'hFF;
            current_target = 4'd0;
        end
    end

endmodule