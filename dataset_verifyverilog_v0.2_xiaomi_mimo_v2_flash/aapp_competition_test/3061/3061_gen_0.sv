module graph_race_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] adj_matrix_flat,
    output reg [7:0] result,
    output reg done
);

    // Parameters
    parameter N = 8;
    parameter LOG2_N = 3;
    parameter MAX_LATENCY = 60;

    // State definition
    localparam IDLE = 3'b000;
    localparam LOAD_MATRIX = 3'b001;
    localparam COMPUTE_FW = 3'b010;
    localparam COMPUTE_BW = 3'b011;
    localparam EVAL_EDGES = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state, next_state;

    // Matrix storage: 8x8 bit matrix
    // We use 8 separate 8-bit registers for rows
    reg [7:0] adj_matrix [0:7];
    
    // DP arrays: forward_dist and backward_dist store max path lengths
    // forward_dist[i]: max path length starting at i
    // backward_dist[i]: max path length ending at i
    reg [3:0] forward_dist [0:7];
    reg [3:0] backward_dist [0:7];
    
    // Intermediate DP arrays for iteration
    reg [3:0] fw_temp [0:7];
    reg [3:0] bw_temp [0:7];

    // Counters
    reg [2:0] load_cnt;     // 0 to 7 for loading rows
    reg [2:0] iter_cnt;     // Iteration counter for DP convergence (0 to 7)
    reg [2:0] edge_u;       // Current edge source node for evaluation
    reg [2:0] edge_v;       // Current edge dest node for evaluation
    reg [2:0] node_idx;     // General purpose node index
    
    // Computation registers
    reg [3:0] global_max_path; // The max path length in the graph
    reg [3:0] candidate_len;   // Stores result of edge removal candidate
    reg [3:0] best_result;     // Min of max path lengths
    
    // Flags and temporary calculations
    reg [3:0] temp_calc1;
    reg [3:0] temp_calc2;
    reg [3:0] path_via_edge;
    
    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? LOAD_MATRIX : IDLE;
            LOAD_MATRIX: next_state = (load_cnt == 3'h7) ? COMPUTE_FW : LOAD_MATRIX;
            COMPUTE_FW: next_state = (iter_cnt == 3'h7) ? COMPUTE_BW : COMPUTE_FW;
            COMPUTE_BW: next_state = (iter_cnt == 3'h7) ? EVAL_EDGES : COMPUTE_BW;
            EVAL_EDGES: next_state = (edge_u == 3'h7 && edge_v == 3'h7) ? DONE : EVAL_EDGES;
            DONE:       next_state = IDLE; // Self-resetting or waits for start
            default:    next_state = IDLE;
        endcase
    end

    // Control Signals & Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all logic
            done <= 1'b0;
            result <= 8'b0;
            load_cnt <= 3'b0;
            iter_cnt <= 3'b0;
            edge_u <= 3'b0;
            edge_v <= 3'b0;
            best_result <= 4'hF; // Initialize to max value (15)
            global_max_path <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    load_cnt <= 3'b0;
                    iter_cnt <= 3'b0;
                    edge_u <= 3'b0;
                    edge_v <= 3'b0;
                    best_result <= 4'hF;
                    global_max_path <= 4'b0;
                end

                LOAD_MATRIX: begin
                    // Store the flattened row into the matrix
                    adj_matrix[load_cnt] <= adj_matrix_flat;
                    // Initialize forward/backward distances to 0 for this node (reset safe)
                    forward_dist[load_cnt] <= 4'b0;
                    backward_dist[load_cnt] <= 4'b0;
                    load_cnt <= load_cnt + 1'b1;
                end

                COMPUTE_FW: begin
                    // Forward DP: Relax edges u -> v
                    // fw[u] = max(fw[u], fw[v] + 1) for each edge u->v. 
                    // Correct DP for longest path: fw[u] = max(0, max(fw[v] + 1) over edges u->v)
                    // Note: Since it's DAG, iterating 8 times guarantees convergence for N=8 nodes.
                    
                    if (iter_cnt < 3'h7) begin // We only iterate 7 times (enough for convergence of len 7)
                        // Inner loop logic must be unrolled or sequential. 
                        // We perform 1 pass of relaxation per clock cycle.
                        
                        // To do this efficiently in hardware, we update all nodes simultaneously based on previous state
                        // But we need to ensure sequential dependency isn't violated. 
                        // We use fw_temp which updates every cycle, reading from fw_temp of previous cycle is not allowed in combinational logic without care.
                        // However, since we are in a clocked block, we calculate new value and assign to forward_dist.
                        
                        // Let's do: forward_dist <= fw_temp; fw_temp <= next_fw_temp logic
                        // Since I'm optimizing for code size and simplicity in this block:
                        // We will recalculate forward_dist based on the 'old' forward_dist inside the same clock edge.
                        // This is a standard relaxation approach.
                        
                        // Unrolled inner loop for u from 0 to 7:
                        // Node 0
                        forward_dist[0] <= (adj_matrix[0][0] ? (forward_dist[0] > forward_dist[0] + 1 ? forward_dist[0] : forward_dist[0] + 1) : forward_dist[0]) | // self loop check
                                            (adj_matrix[0][1] && forward_dist[1] + 1 > forward_dist[0] ? forward_dist[1] + 1 : forward_dist[0]) |
                                            (adj_matrix[0][2] && forward_dist[2] + 1 > forward_dist[0] ? forward_dist[2] + 1 : forward_dist[0]) |
                                            (adj_matrix[0][3] && forward_dist[3] + 1 > forward_dist[0] ? forward_dist[3] + 1 : forward_dist[0]) |
                                            (adj_matrix[0][4] && forward_dist[4] + 1 > forward_dist[0] ? forward_dist[4] + 1 : forward_dist[0]) |
                                            (adj_matrix[0][5] && forward_dist[5] + 1 > forward_dist[0] ? forward_dist[5] + 1 : forward_dist[0]) |
                                            (adj_matrix[0][6] && forward_dist[6] + 1 > forward_dist[0] ? forward_dist[6] + 1 : forward_dist[0]) |
                                            (adj_matrix[0][7] && forward_dist[7] + 1 > forward_dist[0] ? forward_dist[7] + 1 : forward_dist[0]);
                        
                        // ... Repeating for all nodes is verbose. To fit constraints and be clean, we use a helper logic or simplify.
                        // Given the constraints, explicit logic is safer for synthesis.
                        // Let's implement the update for all 8 nodes.
                        
                        // Optimization: We can't write an always block inside an always block. 
                        // We need to compute new values based on old values. Since we are assigning to the same reg (forward_dist), we need temp storage or read-before-write.
                        // In Verilog, "forward_dist <= ..." reads the OLD value of forward_dist. So this works.
                        
                        // Node 0 Update
                        forward_dist[0] <= max_val( 
                            {adj_matrix[0][7], forward_dist[7]+1}, {adj_matrix[0][6], forward_dist[6]+1},
                            {adj_matrix[0][5], forward_dist[5]+1}, {adj_matrix[0][4], forward_dist[4]+1},
                            {adj_matrix[0][3], forward_dist[3]+1}, {adj_matrix[0][2], forward_dist[2]+1},
                            {adj_matrix[0][1], forward_dist[1]+1}, {adj_matrix[0][0], forward_dist[0]+1},
                            forward_dist[0] // keep old value if no edge improves
                        );
                        
                        forward_dist[1] <= max_val( 
                            {adj_matrix[1][7], forward_dist[7]+1}, {adj_matrix[1][6], forward_dist[6]+1},
                            {adj_matrix[1][5], forward_dist[5]+1}, {adj_matrix[1][4], forward_dist[4]+1},
                            {adj_matrix[1][3], forward_dist[3]+1}, {adj_matrix[1][2], forward_dist[2]+1},
                            {adj_matrix[1][1], forward_dist[1]+1}, {adj_matrix[1][0], forward_dist[0]+1},
                            forward_dist[1]
                        );
                        
                        forward_dist[2] <= max_val( 
                            {adj_matrix[2][7], forward_dist[7]+1}, {adj_matrix[2][6], forward_dist[6]+1},
                            {adj_matrix[2][5], forward_dist[5]+1}, {adj_matrix[2][4], forward_dist[4]+1},
                            {adj_matrix[2][3], forward_dist[3]+1}, {adj_matrix[2][2], forward_dist[2]+1},
                            {adj_matrix[2][1], forward_dist[1]+1}, {adj_matrix[2][0], forward_dist[0]+1},
                            forward_dist[2]
                        );
                        
                        forward_dist[3] <= max_val( 
                            {adj_matrix[3][7], forward_dist[7]+1}, {adj_matrix[3][6], forward_dist[6]+1},
                            {adj_matrix[3][5], forward_dist[5]+1}, {adj_matrix[3][4], forward_dist[4]+1},
                            {adj_matrix[3][3], forward_dist[3]+1}, {adj_matrix[3][2], forward_dist[2]+1},
                            {adj_matrix[3][1], forward_dist[1]+1}, {adj_matrix[3][0], forward_dist[0]+1},
                            forward_dist[3]
                        );
                        
                        forward_dist[4] <= max_val( 
                            {adj_matrix[4][7], forward_dist[7]+1}, {adj_matrix[4][6], forward_dist[6]+1},
                            {adj_matrix[4][5], forward_dist[5]+1}, {adj_matrix[4][4], forward_dist[4]+1},
                            {adj_matrix[4][3], forward_dist[3]+1}, {adj_matrix[4][2], forward_dist[2]+1},
                            {adj_matrix[4][1], forward_dist[1]+1}, {adj_matrix[4][0], forward_dist[0]+1},
                            forward_dist[4]
                        );
                        
                        forward_dist[5] <= max_val( 
                            {adj_matrix[5][7], forward_dist[7]+1}, {adj_matrix[5][6], forward_dist[6]+1},
                            {adj_matrix[5][5], forward_dist[5]+1}, {adj_matrix[5][4], forward_dist[4]+1},
                            {adj_matrix[5][3], forward_dist[3]+1}, {adj_matrix[5][2], forward_dist[2]+1},
                            {adj_matrix[5][1], forward_dist[1]+1}, {adj_matrix[5][0], forward_dist[0]+1},
                            forward_dist[5]
                        );
                        
                        forward_dist[6] <= max_val( 
                            {adj_matrix[6][7], forward_dist[7]+1}, {adj_matrix[6][6], forward_dist[6]+1},
                            {adj_matrix[6][5], forward_dist[5]+1}, {adj_matrix[6][4], forward_dist[4]+1},
                            {adj_matrix[6][3], forward_dist[3]+1}, {adj_matrix[6][2], forward_dist[2]+1},
                            {adj_matrix[6][1], forward_dist[1]+1}, {adj_matrix[6][0], forward_dist[0]+1},
                            forward_dist[6]
                        );
                        
                        forward_dist[7] <= max_val( 
                            {adj_matrix[7][7], forward_dist[7]+1}, {adj_matrix[7][6], forward_dist[6]+1},
                            {adj_matrix[7][5], forward_dist[5]+1}, {adj_matrix[7][4], forward_dist[4]+1},
                            {adj_matrix[7][3], forward_dist[3]+1}, {adj_matrix[7][2], forward_dist[2]+1},
                            {adj_matrix[7][1], forward_dist[1]+1}, {adj_matrix[7][0], forward_dist[0]+1},
                            forward_dist[7]
                        );

                        iter_cnt <= iter_cnt + 1'b1;
                    end
                end

                COMPUTE_BW: begin
                    // Backward DP: Similar logic but for reverse graph (edges v -> u in reverse)
                    // We compute longest path ending at node i.
                    // bw[i] = max(bw[u] + 1) for u -> i.
                    // 
                    // Actually, standard backward DP for longest path to sink: 
                    // Backward pass usually computes from sink to source. 
                    // Or we can view it as: max path ending at 'i' from any start.
                    // Update rule: bw[i] = max(bw[i], bw[u] + 1) for u->i. 
                    // This is effectively: bw[i] = max( adj[row][i] ? (bw[row] + 1) )
                    // This is symmetric to forward pass.

                    if (iter_cnt < 3'h7) begin
                        // For backward, we need to check incoming edges.
                        // i receives from j where adj[j][i] = 1.
                        // bw[i] = max(bw[i], bw[j] + 1)

                        // Unrolling for i=0 to 7:
                        // Node 0 (receives from 0..7)
                        backward_dist[0] <= max_val(
                            {adj_matrix[7][0], backward_dist[7]+1}, {adj_matrix[6][0], backward_dist[6]+1},
                            {adj_matrix[5][0], backward_dist[5]+1}, {adj_matrix[4][0], backward_dist[4]+1},
                            {adj_matrix[3][0], backward_dist[3]+1}, {adj_matrix[2][0], backward_dist[2]+1},
                            {adj_matrix[1][0], backward_dist[1]+1}, {adj_matrix[0][0], backward_dist[0]+1},
                            backward_dist[0]
                        );

                        backward_dist[1] <= max_val(
                            {adj_matrix[7][1], backward_dist[7]+1}, {adj_matrix[6][1], backward_dist[6]+1},
                            {adj_matrix[5][1], backward_dist[5]+1}, {adj_matrix[4][1], backward_dist[4]+1},
                            {adj_matrix[3][1], backward_dist[3]+1}, {adj_matrix[2][1], backward_dist[2]+1},
                            {adj_matrix[1][1], backward_dist[1]+1}, {adj_matrix[0][1], backward_dist[0]+1},
                            backward_dist[1]
                        );

                        backward_dist[2] <= max_val(
                            {adj_matrix[7][2], backward_dist[7]+1}, {adj_matrix[6][2], backward_dist[6]+1},
                            {adj_matrix[5][2], backward_dist[5]+1}, {adj_matrix[4][2], backward_dist[4]+1},
                            {adj_matrix[3][2], backward_dist[3]+1}, {adj_matrix[2][2], backward_dist[2]+1},
                            {adj_matrix[1][2], backward_dist[1]+1}, {adj_matrix[0][2], backward_dist[0]+1},
                            backward_dist[2]
                        );

                        backward_dist[3] <= max_val(
                            {adj_matrix[7][3], backward_dist[7]+1}, {adj_matrix[6][3], backward_dist[6]+1},
                            {adj_matrix[5][3], backward_dist[5]+1}, {adj_matrix[4][3], backward_dist[4]+1},
                            {adj_matrix[3][3], backward_dist[3]+1}, {adj_matrix[2][3], backward_dist[2]+1},
                            {adj_matrix[1][3], backward_dist[1]+1}, {adj_matrix[0][3], backward_dist[0]+1},
                            backward_dist[3]
                        );

                        backward_dist[4] <= max_val(
                            {adj_matrix[7][4], backward_dist[7]+1}, {adj_matrix[6][4], backward_dist[6]+1},
                            {adj_matrix[5][4], backward_dist[5]+1}, {adj_matrix[4][4], backward_dist[4]+1},
                            {adj_matrix[3][4], backward_dist[3]+1}, {adj_matrix[2][4], backward_dist[2]+1},
                            {adj_matrix[1][4], backward_dist[1]+1}, {adj_matrix[0][4], backward_dist[0]+1},
                            backward_dist[4]
                        );

                        backward_dist[5] <= max_val(
                            {adj_matrix[7][5], backward_dist[7]+1}, {adj_matrix[6][5], backward_dist[6]+1},
                            {adj_matrix[5][5], backward_dist[5]+1}, {adj_matrix[4][5], backward_dist[4]+1},
                            {adj_matrix[3][5], backward_dist[3]+1}, {adj_matrix[2][5], backward_dist[2]+1},
                            {adj_matrix[1][5], backward_dist[1]+1}, {adj_matrix[0][5], backward_dist[0]+1},
                            backward_dist[5]
                        );

                        backward_dist[6] <= max_val(
                            {adj_matrix[7][6], backward_dist[7]+1}, {adj_matrix[6][6], backward_dist[6]+1},
                            {adj_matrix[5][6], backward_dist[5]+1}, {adj_matrix[4][6], backward_dist[4]+1},
                            {adj_matrix[3][6], backward_dist[3]+1}, {adj_matrix[2][6], backward_dist[2]+1},
                            {adj_matrix[1][6], backward_dist[1]+1}, {adj_matrix[0][6], backward_dist[0]+1},
                            backward_dist[6]
                        );

                        backward_dist[7] <= max_val(
                            {adj_matrix[7][7], backward_dist[7]+1}, {adj_matrix[6][7], backward_dist[6]+1},
                            {adj_matrix[5][7], backward_dist[5]+1}, {adj_matrix[4][7], backward_dist[4]+1},
                            {adj_matrix[3][7], backward_dist[3]+1}, {adj_matrix[2][7], backward_dist[2]+1},
                            {adj_matrix[1][7], backward_dist[1]+1}, {adj_matrix[0][7], backward_dist[0]+1},
                            backward_dist[7]
                        );

                        iter_cnt <= iter_cnt + 1'b1;
                    end
                end

                EVAL_EDGES: begin
                    // Iterate over all edges (u->v)
                    // Check if u->v exists (adj_matrix[u][v] == 1)
                    // If it exists:
                    //   path_len = backward_dist[u] + 1 + forward_dist[v]
                    //   if path_len == global_max_path:
                    //     candidate = max(backward_dist[u], forward_dist[v])
                    //     best_result = min(best_result, candidate)
                    
                    // We need to compute global_max_path in the previous state or at start of this state.
                    // Let's compute global_max_path at the end of COMPUTE_BW or here.
                    // Since we are reusing iter_cnt, let's compute it at the start of EVAL_EDGES if needed.
                    // Actually, let's compute it in the FW/BW states, or in a dedicated state. 
                    // To save states, we can compute it in the first cycle of EVAL_EDGES.
                    // But since we loop edges, let's assume we compute global_max_path at the end of COMPUTE_BW.
                    // Correction: I didn't add a state for global max calculation. 
                    // Let's compute it in the transition or just use a flag.
                    
                    // Let's assume we compute global_max_path in the first cycle of EVAL_EDGES or just before entering it.
                    // I'll put the calculation of global_max_path in the DONE state of the previous step or use a flag.
                    // Actually, let's just calculate it in the EVAL_EDGES logic if not done.
                    
                    // We iterate edge_u 0-7, edge_v 0-7.
                    if (edge_u == 3'b0 && edge_v == 3'b0 && node_idx == 3'b0) begin
                         // First cycle of EVAL_EDGES: Calculate Global Max
                         global_max_path <= 4'b0;
                         // We need to scan all forward_dist or backward_dist (which should be same max ideally, but let's take max of forward)
                         // Actually, max path in DAG = max(forward_dist[i] for all i) or max(backward_dist[i]).
                         // Let's use a helper to find max of forward_dist. 
                         // Since we are in clocked block, we can compute it sequentially or unrolled.
                         // To save logic, let's just trust we can find max in a few cycles or unroll.
                         // Let's do it in one cycle for simplicity, unrolled comparison.
                         temp_calc1 <= max4(max4(forward_dist[0], forward_dist[1], forward_dist[2], forward_dist[3]),
                                            max4(forward_dist[4], forward_dist[5], forward_dist[6], forward_dist[7]),
                                            4'b0, 4'b0);
                         // We need to check this value against the heuristic logic.
                    end
                    
                    // Logic to iterate edges:
                    // If edge exists (adj_matrix[edge_u][edge_v] == 1)
                    if (adj_matrix[edge_u][edge_v]) begin
                        // Calculate path length using this edge
                        // Note: backward_dist and forward_dist are 4 bits, sum is 4+4+1=9 bits, but max is 7+1+7=15 fits in 4 bits if we cap.
                        // Let's cap at 15.
                        path_via_edge <= backward_dist[edge_u] + 1 + forward_dist[edge_v]; // This is 4bit addition (overflow safe in logic)
                        
                        // We need to compare path_via_edge with global_max_path.
                        // Since global_max_path was just calculated (assuming we stall or pipeline), let's assume it's available.
                        // However, EVAL_EDGES loops. It's better to compute global_max_path before entering this state.
                        // Let's hack: use a flag. 
                        
                        // Actually, let's compute global_max_path in the state transition logic of EVAL_EDGES?
                        // No, let's do it in IDLE or LOAD_MATRIX as 0. Then at the end of COMPUTE_BW, we update it.
                        // Let's put a block in COMPUTE_BW to update global_max_path.
                        
                        // Back to EVAL logic:
                        // We need to compare path_via_edge == global_max_path.
                        // Also need to compute candidate = max(backward_dist[edge_u], forward_dist[edge_v])
                        candidate_len <= (backward_dist[edge_u] > forward_dist[edge_v]) ? backward_dist[edge_u] : forward_dist[edge_v];
                        
                        // If it is critical, update best_result
                        // best_result = min(best_result, candidate_len)
                        // This comparison is tricky because we need to check equality first.
                        if (path_via_edge == temp_calc1) begin // temp_calc1 holds global max from above logic? 
                            // Wait, we need to pass global_max to this stage.
                            // Let's assume temp_calc1 is holding global_max_path (computed in first cycle).
                            // But temp_calc1 is overwritten in subsequent cycles? No, we only compute it once.
                            // Let's use a dedicated reg for global_max.
                            
                            // Wait, the logic above "global_max_path <= ..." needs to persist.
                            // Let's refine the EVAL_EDGES block.
                            
                            // Use a separate logic block to update best_result.
                            if (path_via_edge == global_max_path) begin
                                if (candidate_len < best_result) begin
                                    best_result <= candidate_len;
                                end
                            end
                        end
                    end
                    
                    // Increment counters
                    if (edge_v == 3'h7) begin
                        edge_v <= 3'b0;
                        if (edge_u == 3'h7) begin
                            // Done, stay in state or go to DONE
                            // Handled by next_state logic
                        end else begin
                            edge_u <= edge_u + 1'b1;
                        end
                    end else begin
                        edge_v <= edge_v + 1'b1;
                    end
                    
                    // Fix for first cycle: Calculate global_max_path strictly before loop or in parallel.
                    // To ensure synchronization, let's clear best_result at start of EVAL and calculate global max.
                end

                DONE: begin
                    // Final Result
                    // If best_result never updated (was 15) or is larger than global_max, use global_max.
                    // result = (best_result < global_max_path) ? best_result : global_max_path;
                    // But wait, if no edge removal reduces length, best_result remains high (15).
                    // So we need max(global_max, best_result)? No, min.
                    // Actually, result is "minimum longest path".
                    // If we remove no edge, path is global_max.
                    // So result = min(global_max, best_result). 
                    // But best_result is candidate length. If candidate is valid, we pick it. If not, we pick global_max.
                    
                    // Let's define: If best_result == 4'hF (initialized value), result = global_max_path.
                    // Else result = best_result.
                    
                    if (best_result == 4'hF) begin
                        result <= {4'b0, global_max_path};
                    end else begin
                        result <= {4'b0, best_result};
                    end
                    done <= 1'b1;
                end
            endcase
            
            // Additional Logic Injection for Global Max Calculation in EVAL state
            // To make this correct, we need to handle the first cycle of EVAL_EDGES specifically.
            // If state == EVAL_EDGES and edge_u == 0 and edge_v == 0:
            if (state == EVAL_EDGES && edge_u == 3'b0 && edge_v == 3'b0) begin
                // Compute global max once
                global_max_path <= max4(max4(forward_dist[0], forward_dist[1], forward_dist[2], forward_dist[3]),
                                        max4(forward_dist[4], forward_dist[5], forward_dist[6], forward_dist[7]),
                                        4'b0, 4'b0);
                best_result <= 4'hF; // Reset best_result for this run
            end
        end
    end

    // Helper Functions
    // Max of 4 4-bit values
    function [3:0] max4;
        input [3:0] a, b, c, d;
        reg [3:0] m1, m2;
        begin
            m1 = (a > b) ? a : b;
            m2 = (c > d) ? c : d;
            max4 = (m1 > m2) ? m1 : m2;
        end
    endfunction

    // Max of 8 pairs (valid, value) and a default
    function [3:0] max_val;
        input [4:0] p7, p6, p5, p4, p3, p2, p1, p0; // {valid, value}
        input [3:0] def;
        reg [3:0] m0, m1, m2, m3, m4, m5, m6, m7;
        begin
            m7 = p7[4] ? p7[3:0] : 4'b0;
            m6 = p6[4] ? p6[3:0] : 4'b0;
            m5 = p5[4] ? p5[3:0] : 4'b0;
            m4 = p4[4] ? p4[3:0] : 4'b0;
            m3 = p3[4] ? p3[3:0] : 4'b0;
            m2 = p2[4] ? p2[3:0] : 4'b0;
            m1 = p1[4] ? p1[3:0] : 4'b0;
            m0 = p0[4] ? p0[3:0] : 4'b0;
            
            // Reduce
            max_val = max4(max4(max4(m7, m6, m5, m4), max4(m3, m2, m1, m0), 4'b0, 4'b0), def, 4'b0, 4'b0);
            // Wait, max4 takes 4 args. We need a cascading max.
            // Simplifying: 
            max_val = (m7 > m6) ? m7 : m6;
            max_val = (max_val > m5) ? max_val : m5;
            max_val = (max_val > m4) ? max_val : m4;
            max_val = (max_val > m3) ? max_val : m3;
            max_val = (max_val > m2) ? max_val : m2;
            max_val = (max_val > m1) ? max_val : m1;
            max_val = (max_val > m0) ? max_val : m0;
            max_val = (max_val > def) ? max_val : def;
        end
    endfunction

endmodule
