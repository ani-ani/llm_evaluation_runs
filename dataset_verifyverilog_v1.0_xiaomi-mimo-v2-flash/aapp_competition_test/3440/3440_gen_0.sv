module flight_review_planner (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] config_addr,
    input wire [23:0] config_data,
    input wire config_valid,
    output reg [23:0] result,
    output reg done
);

    // Parameters for N=8 nodes (Node 0 is Stockholm)
    localparam integer N = 8;
    localparam integer N_LOG2 = 3;
    localparam integer NUM_MASKS = 256; // 2^8
    localparam [23:0] INF = 24'hFFFFFF;

    // State Definition
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] LOAD      = 4'd1;
    localparam [3:0] FLOYD_K   = 4'd2;
    localparam [3:0] FLOYD_I   = 4'd3;
    localparam [3:0] FLOYD_J   = 4'd4;
    localparam [3:0] DP_INIT   = 4'd5;
    localparam [3:0] DP_ITER   = 4'd6;
    localparam [3:0] DP_EXTEND = 4'd7;
    localparam [3:0] FINISH    = 4'd8;
    localparam [3:0] DONE_S    = 4'd9;

    // Registers and State
    reg [3:0] state, next_state;
    reg [3:0] cycle_count;
    
    // Addressing Registers
    reg [N_LOG2-1:0] i, j, k, u, v, w;
    reg [7:0] mask, next_mask; // mask can be up to 255 for N=8
    reg [7:0] required_mask;

    // BRAM Inference for Dist Matrix (8x8) and DP Table (256x8)
    // dist RAM: Port A (Write/Read), Port B (Read)
    reg [23:0] dist [0:N-1][0:N-1];
    reg [23:0] dp [0:NUM_MASKS-1][0:N-1];
    
    // Temporal Registers for Arithmetic
    reg [23:0] dist_u_w;
    reg [23:0] dist_u_v;
    reg [23:0] dp_val;
    reg [23:0] new_cost;
    reg [23:0] final_min;
    
    // Combinational Logic for comparison
    wire [23:0] sum_val = dist_u_w + dist[j][k]; // For Floyd
    wire [23:0] sum_cost = dp[mask][u] + dist[u][v]; // For DP

    // State Machine Synchronous Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            i <= 3'd0; j <= 3'd0; k <= 3'd0;
            u <= 3'd0; v <= 3'd0; w <= 3'd0;
            mask <= 8'd0;
            next_mask <= 8'd0;
            required_mask <= 8'd0;
            dist_u_w <= 24'd0;
            dist_u_v <= 24'd0;
            dp_val <= 24'd0;
            new_cost <= 24'd0;
            final_min <= 24'd0;
        end else begin
            state <= next_state;
            
            // --- State Transitions & Operations ---
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        // Initialize dist matrix with INF (clear old data)
                        // We will do this implicitly by overwrite or assume user loads all
                        // Reset loop counters
                        k <= 3'd0;
                        i <= 3'd0;
                        j <= 3'd0;
                        mask <= 8'd1; // Start from mask {0}
                    end
                end

                LOAD: begin
                    // Loading handled in next_state logic or continuous
                    // We assume config_valid handles the write
                end

                FLOYD_K: begin
                    i <= 3'd0;
                end

                FLOYD_I: begin
                    j <= 3'd0;
                    dist_u_w <= dist[i][k]; // Pre-fetch for P&R
                end

                FLOYD_J: begin
                    // Floyd-Warshall Update
                    if (dist_u_w != INF && dist[j][k] != INF) begin
                        // Optimization: dist[i][j] <= min(dist[i][j], dist_u_w + dist[j][k])
                        // We handle min in combinational logic below or here
                        // Let's update register here if logic allows, or use temp
                        // Using dist_u_w + dist[j][k] -> sum_val
                        if (sum_val < dist[i][j]) begin
                            dist[i][j] <= sum_val;
                        end
                    end
                end

                DP_INIT: begin
                    // Initialize DP table with INF
                    // We use a dedicated 'clearing' loop if needed, or just overwrite
                    // Here we set dp[1][0] = 0 (mask 1, node 0)
                    // Note: dp[0][*] implicitly INF
                    dp[1][0] <= 24'd0;
                    mask <= 8'd1; // Start iteration from mask 1
                    // We need a flag to indicate DP init done
                    // We will iterate mask from 1 to 255
                end

                DP_ITER: begin
                    // Check if u is in current mask
                    // We iterate u from 0 to N-1
                    if ((mask[u]) && dp[mask][u] != INF) begin
                        // Pre-fetch dp value for extension
                        dp_val <= dp[mask][u];
                        v <= 3'd0; // Start checking next node v
                    end
                end

                DP_EXTEND: begin
                    // Try to go from u to v
                    if (mask[v] == 0) begin // v not in mask
                        if (dist[u][v] != INF && dp_val != INF) begin
                            next_mask <= mask | (1 << v);
                            new_cost <= dp_val + dist[u][v]; // sum_cost logic
                            // Update dp in next cycle (combinational check vs write)
                            // Check min against existing dp[next_mask][v]
                            if (new_cost < dp[next_mask][v]) begin
                                dp[next_mask][v] <= new_cost;
                            end
                        end
                    end
                end

                FINISH: begin
                    // Find minimum cost to return to 0
                    // Iterate u over required nodes
                    // Check dp[required_mask][u] + dist[u][0]
                    if (dp[required_mask][u] != INF && dist[u][0] != INF) begin
                        if (dp[required_mask][u] + dist[u][0] < final_min) begin
                            final_min <= dp[required_mask][u] + dist[u][0];
                        end
                    end
                end

                DONE_S: begin
                    result <= final_min;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic (Combinational)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end

            LOAD: begin
                if (load_done) next_state = FLOYD_K;
                // load_done is asserted by testbench when config finishes
            end

            FLOYD_K: begin
                if (k >= N) next_state = DP_INIT; // Floyd Done
                else next_state = FLOYD_I;
            end

            FLOYD_I: begin
                if (i >= N) next_state = begin
                    if (k == N-1) DP_INIT
                    else FLOYD_K;
                end else next_state = FLOYD_J;
            end

            FLOYD_J: begin
                if (j == N-1) begin
                    if (i == N-1) begin
                        if (k == N-1) next_state = DP_INIT;
                        else next_state = FLOYD_K;
                    end else next_state = FLOYD_I;
                end else next_state = FLOYD_J;
            end
            // Correction for FLOYD loops:
            // k loop: 0 to N-1
            // i loop: 0 to N-1
            // j loop: 0 to N-1
            // The inner logic above is slightly messy. 
            // Let's structure it cleanly:
            // Logic for FLOYD loops is purely for-loops unrolled or sequential.
            // Sequential implementation:
            // FLOYD_K: if k < N, go I, else DP_INIT
            // FLOYD_I: if i < N, go J, else K
            // FLOYD_J: if j < N, j++, else i++
            // FLOYD_J updates dist[i][j].
            // We need to verify the update logic in FLOYD_J.
            
            // Corrected Floyd Logic:
            FLOYD_K: next_state = (k >= N) ? DP_INIT : FLOYD_I;
            FLOYD_I: next_state = (i >= N) ? FLOYD_K : FLOYD_J;
            FLOYD_J: next_state = (j >= N) ? FLOYD_I : FLOYD_J;
            
            // Wait states for memory read/propagation if needed (assuming block RAM with 1 cycle latency)
            // We assume dist reads are valid in the same cycle.

            DP_INIT: begin
                // After initializing dp[1][0], go to DP_ITER
                next_state = DP_ITER;
            end

            DP_ITER: begin
                // Check if we are done with all masks
                if (mask > (1 << N) - 1) next_state = FINISH;
                else next_state = DP_EXTEND; // Start extending from current u
            end

            DP_EXTEND: begin
                // Check all v
                if (v >= N) next_state = DP_ITER;
                else next_state = DP_EXTEND;
            end

            FINISH: begin
                // Loop through u (required nodes) to find min loopback
                if (u >= N) next_state = DONE_S;
                else next_state = FINISH;
            end

            DONE_S: next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

    // Load Logic (Separated for clarity)
    // We use a separate block to handle the configuration write
    // Handle updates for Floyd and DP loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            // Handle Load
            if (config_valid && state == LOAD) begin
                if (config_addr == 3'b000) begin
                    // Config Data is [row][col] packed? 
                    // Or separate control. Assume config_data contains cost.
                    // We need row/col info. 
                    // Let's assume config_addr indexes the matrix linearly (0-63 for N=8)
                    // Or we use config_data[7:0] as row, [15:8] as col, [23:16] as cost
                    // For this design, let's assume the testbench provides:
                    // config_data[15:8] = row, config_data[7:0] = col, config_data[23:16] = cost
                    // Actually, simpler: Testbench generates address. 
                    // Let's define: config_addr is ignored for matrix, or used as offset.
                    // Let's use: config_valid loads into dist[config_data[7:4]][config_data[3:0]] = config_data[23:8]
                    // Wait, standard interface: 
                    // config_addr[2:0] = 0 (Data Phase)
                    // config_data[7:4] = Row, config_data[3:0] = Col, config_data[23:8] = Cost
                    // OR required mask input on different address.
                    // Let's strictly define:
                    // If config_addr == 0: Dist Matrix Write (Row in config_data[10:8], Col in config_data[7:5], Cost in config_data[23:0])
                    // Actually, just map flat index.
                    // config_addr == 0: dist[config_data[7:4]][config_data[3:0]] <= config_data[23:8]
                    // config_addr == 1: required_mask <= config_data[7:0]
                    dist[config_data[7:4]][config_data[3:0]] <= config_data[23:8];
                end else if (config_addr == 3'b001) begin
                    required_mask <= config_data[7:0];
                end
            end

            // Handle Floyd Loop Counters
            if (state == FLOYD_K && next_state == FLOYD_I) begin
                // Just entered K loop (or incrementing K)
                // We increment K at the end of I loop completion
            end
            
            // Update Counters based on transitions
            if (state == FLOYD_I && next_state == FLOYD_K) begin
                k <= k + 1;
                i <= 0;
            end
            if (state == FLOYD_J && next_state == FLOYD_I) begin
                i <= i + 1;
                j <= 0;
            end
            if (state == FLOYD_J) begin
                if (next_state == FLOYD_J) begin
                    j <= j + 1; // Increment counter for next cycle
                end
            end

            // Handle DP Loop Counters
            if (state == DP_ITER && next_state == DP_EXTEND) begin
                // We found a valid u, start iterating v
                // v is initialized to 0 in DP_ITER logic above
            end
            
            // DP_ITER state logic update for U and Mask
            // If we are in DP_EXTEND and move to DP_ITER (i.e., finished v loop)
            if (state == DP_EXTEND && next_state == DP_ITER) begin
                // Continue checking current u? No, move to next u.
                u <= u + 1;
                // If u reaches N, move to next mask
                if (u >= N - 1) begin
                    mask <= mask + 1;
                    u <= 0;
                end
            end
            // If we are in DP_ITER and u is NOT in mask, skip to next u immediately
            if (state == DP_ITER && next_state == DP_EXTEND) begin
                // If u not in mask, DP_EXTEND will skip writing, but we need to increment u in this cycle?
                // No, we handle that in the 'always @(*)' next_state logic or here.
                // Actually, if u not in mask, we should not enter DP_EXTEND for processing.
                // We check the condition: if dp[mask][u] == INF, it means we skip extension.
                // But we must still iterate u.
                // Let's refine DP_ITER next_state: 
                // If dp[mask][u] is INF, skip to next u (or mask if done).
            end

            // Handle DP EXTEND Counter
            if (state == DP_EXTEND && next_state == DP_EXTEND) begin
                v <= v + 1;
            end

            // Handle FINISH Counter
            if (state == FINISH) begin
                if (next_state == FINISH) begin
                    u <= u + 1;
                end
            end
        end
    end

    // Fix Logic for DP_ITER State
    // We need to be careful: if dp[mask][u] is INF, we skip this u immediately.
    // If we skip, we increment u.
    // If u >= N, we increment mask.
    // This requires explicit logic in the state transition or internal counters.
    // Let's create a helper logic block to manage 'skipping' invalid u in DP_ITER
    
    // Overriding the counter update logic for DP_ITER
    // We need to know if we are skipping.
    wire u_in_mask = mask[u];
    wire dp_val_valid = (dp[mask][u] != INF);
    wire should_skip = (u_in_mask == 0) || (dp_val_valid == 0);
    
    // Modifying the counter update block for DP_ITER:
    // This block runs whenever state transitions.
    always @(posedge clk) begin
        if (!rst_n) begin
            // reset
        end else begin
            // If we are in DP_ITER and we decide to skip (because u not in mask or invalid dp)
            // We need to increment u (or mask) immediately in this cycle if next_state is also DP_ITER.
            // But we are in a synchronous block. 
            // We will handle the 'skip' by updating counters if state remains DP_ITER.
            
            if (state == DP_ITER && next_state == DP_ITER) begin
                // We are staying in DP_ITER because we are skipping current u
                u <= u + 1;
                if (u >= N - 1) begin
                    mask <= mask + 1;
                    u <= 0;
                end
            end
        end
    end

    // We must ensure we don't double increment.
    // The 'state == DP_ITER && next_state == DP_ITER' happens when we skip.
    // The 'state == DP_EXTEND && next_state == DP_ITER' happens when we finish v loop.
    // These are distinct cases.

    // Conflict: if state==DP_ITER and we don't skip, we go to DP_EXTEND.
    // In that case, we initialize v to 0 (done in DP_ITER operation block above).
    // We must ensure v is reset when we enter DP_EXTEND from DP_ITER.
    
    // Correcting 'DP_ITER Operation':
    // If u valid, we set v=0 and go to DP_EXTEND.
    // The logic `v <= 3'd0` in the `DP_ITER` case block handles this.

    // Correcting 'DP_EXTEND Operation':
    // If v >= N, we go to DP_ITER. But we need to check if there are more u.
    // The next_state logic handles v >= N -> DP_ITER.
    // In DP_EXTEND, we update v (v++) unless we are finished.

endmodule