module ShortestPath (
    input clk,
    input rst_n,
    input start,
    input [23:0] x_0, x_1, x_2, x_3, x_4, x_5, x_6, x_7,
    input [23:0] x_8, x_9, x_10, x_11, x_12, x_13, x_14, x_15,
    input [23:0] d_0, d_1, d_2, d_3, d_4, d_5, d_6, d_7,
    input [23:0] d_8, d_9, d_10, d_11, d_12, d_13, d_14, d_15,
    input [23:0] r_0, r_1, r_2, r_3, r_4, r_5, r_6, r_7,
    input [23:0] r_8, r_9, r_10, r_11, r_12, r_13, r_14, r_15,
    input [3:0] node_count,
    output reg [255:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] BUILD_EDGES = 2'd1;
    localparam [1:0] DIJKSTRA = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i, j; // Loop counters
    reg [15:0] dist [0:15]; // Distance array
    reg [0:15] visited; // Visited flags
    reg [15:0] adj_weight [0:255]; // Flattened adjacency weights (16x16)
    reg adj_bit [0:255]; // Flattened adjacency matrix bits
    reg [3:0] u; // Node with minimum distance
    reg [15:0] min_dist;
    reg [15:0] alt_dist;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper arrays to simplify access
    reg [23:0] x [0:15];
    reg [23:0] d [0:15];
    reg [23:0] r [0:15];

    integer k;

    // Combinational logic for state transition
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = BUILD_EDGES;
            BUILD_EDGES: if (i >= node_count) next_state = DIJKSTRA;
            DIJKSTRA: if (j >= node_count || cycle_count >= MAX_CYCLES) next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 256'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            u <= 4'd0;
            min_dist <= 16'd0;
            alt_dist <= 16'd0;
            visited <= 16'd0;
            for (k = 0; k < 16; k = k + 1) begin
                dist[k] <= 16'd0;
                x[k] <= 24'd0;
                d[k] <= 24'd0;
                r[k] <= 24'd0;
            end
            for (k = 0; k < 256; k = k + 1) begin
                adj_weight[k] <= 16'd0;
                adj_bit[k] <= 1'b0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    if (start) begin
                        // Load inputs into arrays for easier indexing
                        x[0] <= x_0; x[1] <= x_1; x[2] <= x_2; x[3] <= x_3;
                        x[4] <= x_4; x[5] <= x_5; x[6] <= x_6; x[7] <= x_7;
                        x[8] <= x_8; x[9] <= x_9; x[10] <= x_10; x[11] <= x_11;
                        x[12] <= x_12; x[13] <= x_13; x[14] <= x_14; x[15] <= x_15;
                        d[0] <= d_0; d[1] <= d_1; d[2] <= d_2; d[3] <= d_3;
                        d[4] <= d_4; d[5] <= d_5; d[6] <= d_6; d[7] <= d_7;
                        d[8] <= d_8; d[9] <= d_9; d[10] <= d_10; d[11] <= d_11;
                        d[12] <= d_12; d[13] <= d_13; d[14] <= d_14; d[15] <= d_15;
                        r[0] <= r_0; r[1] <= r_1; r[2] <= r_2; r[3] <= r_3;
                        r[4] <= r_4; r[5] <= r_5; r[6] <= r_6; r[7] <= r_7;
                        r[8] <= r_8; r[9] <= r_9; r[10] <= r_10; r[11] <= r_11;
                        r[12] <= r_12; r[13] <= r_13; r[14] <= r_14; r[15] <= r_15;
                    end
                end

                BUILD_EDGES: begin
                    // Iterate over i (source) and j (destination)
                    // Row-major: i outer, j inner
                    if (i < node_count && j < node_count) begin
                        // Check if edge exists: |x_i - x_j| >= d_i
                        // We handle i==j later or ignore
                        if (x[i] >= x[j]) begin
                            if ((x[i] - x[j]) >= d[i]) begin
                                adj_bit[{i, j}] <= 1'b1;
                                // Weight: r_i + |x_i - x_j|
                                // r_i is Q8.16. |x_i - x_j| is integer (upper 8 bits of difference)
                                // We take upper 8 bits of diff for integer part
                                adj_weight[{i, j}] <= r[i][23:8] + (x[i][23:8] - x[j][23:8]);
                            end else begin
                                adj_bit[{i, j}] <= 1'b0;
                            end
                        end else begin
                            if ((x[j] - x[i]) >= d[i]) begin
                                adj_bit[{i, j}] <= 1'b1;
                                adj_weight[{i, j}] <= r[i][23:8] + (x[j][23:8] - x[i][23:8]);
                            end else begin
                                adj_bit[{i, j}] <= 1'b0;
                            end
                        end
                        
                        // Increment j, reset j if overflow
                        if (j == 4'd15) begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end else begin
                            j <= j + 4'd1;
                        end
                    end
                end

                DIJKSTRA: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Init phase for Dijkstra
                    if (cycle_count == 8'd0) begin
                        // Initialize dist and visited
                        for (k = 0; k < 16; k = k + 1) begin
                            if (k < node_count) begin
                                if (k == 0) dist[k] <= 16'd0;
                                else dist[k] <= 16'hFFFF;
                            end else begin
                                dist[k] <= 16'd0;
                            end
                            visited[k] <= 1'b0;
                        end
                        j <= 4'd0; // Reset j for loop
                    end else begin
                        // Main loop: Select unvisited node u with min dist
                        // We iterate j to find min
                        if (j < node_count) begin
                            if (!visited[j]) begin
                                if (j == 4'd0 || dist[j] < min_dist) begin
                                    u <= j;
                                    min_dist <= dist[j];
                                end
                            end
                            j <= j + 4'd1;
                        end else begin
                            // Selection complete
                            // Mark u as visited (if reachable)
                            if (min_dist < 16'hFFFF) begin
                                visited[u] <= 1'b1;
                                
                                // Relax edges from u
                                // Loop over v (0 to node_count-1)
                                // We use the j counter for this inner loop, reset it first
                                // Need a sub-state or separate counter. 
                                // Using a dedicated state or reusing i/j carefully.
                                // To fit timing: we can iterate in subsequent cycles.
                                // Let's reuse 'i' for the relaxation loop
                                if (i < node_count) begin
                                    if (adj_bit[{u, i}] && !visited[i]) begin
                                        // Update dist if shorter
                                        // Saturating addition
                                        if (dist[u] != 16'hFFFF) begin
                                            alt_dist <= dist[u] + adj_weight[{u, i}];
                                            // Check saturation
                                            if (dist[u] + adj_weight[{u, i}] < dist[u]) begin
                                                // Overflow (wrap around to smaller value is bad in unsigned if we want max)
                                                // Since we use 16-bit, 0xFFFF is max.
                                                // If sum > 65535, it wraps. We treat wrapping as saturation to 65535.
                                                // But 65535 is INF. So we set to INF.
                                                // Actually, if dist[u] is INF (65535), we skip. 
                                                // Max realistic sum is < 65535 if we clamp.
                                            end
                                        end
                                        
                                        // Logic update for dist[i]
                                        // We do the update in a way that avoids multi-driver
                                        // The actual update happens in the combinational check below or next cycle.
                                        // Let's do update directly here, assuming synthesis handles it.
                                        // To be safe, use a temporary check variable.
                                    end
                                    i <= i + 4'd1;
                                end else begin
                                    // One full relaxation pass done (over all v)
                                    // Reset for next main iteration
                                    i <= 4'd0;
                                    j <= 4'd0;
                                    min_dist <= 16'hFFFF;
                                end
                            end else begin
                                // Node u is unreachable (min_dist is INF). 
                                // We are done with the graph (remaining nodes also INF)
                                // Jump to finish state logic handled by transition condition
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    // Pack results into 256-bit output
                    // Index 1 to 15 correspond to nodes 1-15 in graph
                    // Output is 16 16-bit fields.
                    // result[15:0] is node 1, result[31:16] is node 2, etc.
                    // Which matches dist[1], dist[2]...
                    for (k = 0; k < 16; k = k + 1) begin
                        if (k < node_count) begin
                            result[(k*16)+:16] <= dist[k];
                        end else begin
                            result[(k*16)+:16] <= 16'd0;
                        end
                    end
                end
            endcase

            // Corrected Relaxation Logic (Combinational handling within sequential block style)
            // To ensure correctness and synthesis area/timing, we handle the 'alt' check specifically.
            // We split the DIJKSTRA state into sub-cycles effectively.
            // Let's refine the DIJKSTRA state to be robust.
            // Cycle 1: Init
            // Cycle 2..N: Select u (find min)
            // Cycle N+1..M: Relax
            
            // Re-implementing DIJKSTRA with clearer sub-steps inside the always block
            if (state == DIJKSTRA) begin
                // Sub-step 1: Initialization (first cycle)
                if (cycle_count == 8'd1) begin
                    for (k = 0; k < 16; k = k + 1) begin
                        if (k < node_count) begin
                            dist[k] <= (k == 0) ? 16'd0 : 16'hFFFF;
                            visited[k] <= 1'b0;
                        end else begin
                            dist[k] <= 16'd0;
                            visited[k] <= 1'b1;
                        end
                    end
                    u <= 4'd0;
                    min_dist <= 16'hFFFF;
                    j <= 4'd0;
                    i <= 4'd0;
                end else if (cycle_count > 8'd1 && cycle_count < 8'd20) begin
                    // Select Min (Linear scan for N<=16)
                    // We reuse 'j' as the loop variable for selection
                    if (j < node_count) begin
                        if (!visited[j]) begin
                            if (dist[j] < min_dist) begin
                                min_dist <= dist[j];
                                u <= j;
                            end
                        end
                        j <= j + 4'd1;
                    end else begin
                        // Selection complete
                        // If min_dist is still INF, we are done (all remaining unvisited are unreachable)
                        // We can jump to FINISH, but FSM transition handles it.
                        // However, we must skip relaxation if min_dist is INF.
                        if (min_dist == 16'hFFFF) begin
                            // Jump ahead to finish logic
                            // We set a flag to skip relaxation or force transition
                            // For simplicity, we mark all as visited so loop terminates next iteration
                            // But we need to finish the current cycle cleanly.
                        end else begin
                            visited[u] <= 1'b1;
                        end
                        // Reset counters for relaxation loop
                        i <= 4'd0;
                    end
                end else if (cycle_count >= 8'd20) begin
                    // Relax edges from u (if valid u found)
                    if (min_dist < 16'hFFFF && i < node_count) begin
                        // Check edge u -> i
                        if (adj_bit[{u, i}] && !visited[i]) begin
                            // Calculate new distance
                            // r_i + diff is 16-bit integer (stored in adj_weight)
                            // dist[u] is 16-bit.
                            // Check overflow
                            if (dist[u] + adj_weight[{u, i}] < min_dist) begin
                                // Overflow occurred (wrap around), cap at max
                                // But max is 65535 (INF), so we effectively set to INF
                                // If we want to prevent wrap errors for valid sums, we need saturation.
                                // However, since we treat 65535 as INF, any sum > 65535 is effectively INF.
                                // If dist[u] is not INF, and sum wraps, it becomes a small number (bad).
                                // So we must saturate.
                                // If dist[u] + adj > 65535 -> 65535
                                // We can check: if (adj_weight[{u,i}] > (16'hFFFF - dist[u]))
                                if (adj_weight[{u, i}] > (16'hFFFF - dist[u])) begin
                                    alt_dist <= 16'hFFFF;
                                end else begin
                                    alt_dist <= dist[u] + adj_weight[{u, i}];
                                end
                            end else begin
                                alt_dist <= dist[u] + adj_weight[{u, i}];
                            end
                            
                            // Perform update if smaller
                            if (alt_dist < dist[i]) begin
                                dist[i] <= alt_dist;
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Relaxation complete for this u, select next u
                        // Reset selection vars
                        j <= 4'd0;
                        min_dist <= 16'hFFFF;
                        // If we finished relaxation but u was INF, we are done
                        if (min_dist == 16'hFFFF) begin
                            // Force transition to FINISH (handled by FSM next_state logic based on j>=node_count)
                        end
                    end
                end
            end
        end
    end

endmodule