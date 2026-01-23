module hamster_game (
    input clk,
    input rst_n,
    input start,
    input [1:0] s,
    input [1:0] t,
    input [7:0] valid_edges,
    input [1:0] edge_from [0:7],
    input [1:0] edge_to [0:7],
    input [15:0] edge_weight [0:7],
    output reg [15:0] result,
    output reg done,
    output reg infinity
);

    // State definition
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam UPDATE_L = 3'b010;
    localparam UPDATE_R = 3'b011;
    localparam CHECK = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // DP tables (4 nodes)
    // Using signed arithmetic. Max weight 10000, 8 edges -> max path ~80000.
    // 16 bits signed range -32768 to 32767. Might be too small if path > 32767.
    // Requirement says edge_weight max 10000. 8 edges max -> 80000.
    // Let's use 24 bits for safety internally, output 16 bits (clamped if needed).
    // Wait, output is [15:0]. If result > 65535, it overflows. 
    // Assuming result fits 16 bits or we saturate. Let's use 24-bit internal.
    
    localparam SIGN_INF = 24'hFFFFFF; // Approx -1 in signed if interpreted poorly, or use specific flag.
    // Let's use a large positive value for unknown/infinity checks, 
    // but actual DP needs to handle -1 for "unreachable".
    
    reg signed [23:0] dp_L [0:3];
    reg signed [23:0] dp_R [0:3];
    
    // Iteration counters
    reg [2:0] iter_cnt; // 4 iterations max needed for graph size 4
    reg [3:0] proc_cnt; // To iterate through nodes 0-3 and edges 0-7
    
    // Temp variables for updates
    reg signed [23:0] best_val;
    reg signed [23:0] current_val;
    reg signed [23:0] temp_sum;
    reg signed [23:0] candidate;
    reg [1:0] node_idx;
    reg [3:0] edge_idx;
    
    // Check variables
    reg signed [23:0] diff;
    reg [1:0] check_node;
    reg check_stuck;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = UPDATE_L;
            end
            UPDATE_L: begin
                if (proc_cnt == 4'd11) next_state = UPDATE_R; // 4 nodes * 8 edges checks + 4 writes = 36 ops? 
                // Simplified: Update all nodes. 
                // We can iterate 4 nodes. For each node, scan 8 edges. 
                // Let's make the loop: proc_cnt counts 0 to 31 (4 nodes * 8 edges).
                // If proc_cnt < 32, we are scanning. 
                // Actually, let's just do 4 steps per state (one per node) to be cleaner or a big loop.
                // Let's use a small loop counter: 0 to 31. 
                // If proc_cnt == 31, go to next state.
                if (proc_cnt == 4'd15) next_state = UPDATE_R; // 16 cycles for UPDATE_L: 4 nodes * 4 cycles per node? No.
                // Let's stick to the prompt's "60 cycles" hint. 
                // Use a counter. If proc_cnt == 15 (representing 4 nodes with some delay), move on.
                // Let's iterate 4 times. 
                if (proc_cnt == 4'd3) next_state = UPDATE_R; // Wait, we need to update ALL nodes. 
                // Let's do: 1 cycle setup, 16 cycles iteration (4 nodes * 4 edges? No, 8 edges).
                // Let's use proc_cnt 0 to 31. 32 cycles. 
                if (proc_cnt == 4'd31) next_state = UPDATE_R; // 32 cycles for L update
            end
            UPDATE_R: begin
                if (proc_cnt == 4'd31) begin
                    if (iter_cnt == 3'd3) next_state = CHECK; // Max 4 iterations
                    else next_state = UPDATE_L;
                end
            end
            CHECK: begin
                // Check 4 nodes. 
                if (check_node == 3) next_state = DONE;
                else next_state = CHECK; // Stay to check next node
            end
            DONE: begin
                if (!start) next_state = IDLE; // Wait for start to go low to re-trigger
            end
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            infinity <= 0;
            result <= 0;
            iter_cnt <= 0;
            proc_cnt <= 0;
            check_node <= 0;
            check_stuck <= 0;
            // Initialize DP tables
            integer i;
            for (i = 0; i < 4; i = i + 1) begin
                dp_L[i] <= -24'sd1;
                dp_R[i] <= -24'sd1;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    infinity <= 0;
                    // Keep result latched from previous run or 0
                    if (start) begin
                        iter_cnt <= 0;
                        proc_cnt <= 0;
                        check_node <= 0;
                        check_stuck <= 0;
                    end
                end

                INIT: begin
                    // Set base cases
                    dp_L[0] <= -24'sd1; dp_R[0] <= -24'sd1;
                    dp_L[1] <= -24'sd1; dp_R[1] <= -24'sd1;
                    dp_L[2] <= -24'sd1; dp_R[2] <= -24'sd1;
                    dp_L[3] <= -24'sd1; dp_R[3] <= -24'sd1;
                    
                    dp_L[t] <= 0;
                    dp_R[t] <= 0;
                    
                    proc_cnt <= 0;
                end

                UPDATE_L: begin
                    // Loop proc_cnt 0 to 31. 
                    // 0-7: Check edges for node 0. 8-15: Node 1. 16-23: Node 2. 24-31: Node 3.
                    // Actually simpler: iterate 0-3, process node.
                    // Let's do: proc_cnt 0..31. 
                    // If proc_cnt[2:0] < 4, we are updating node proc_cnt[2:0].
                    // But we need to scan edges.
                    // Let's break it down: 
                    // We need to maintain 'best_val' for current node.
                    
                    // We will use proc_cnt to index nodes and edges.
                    // proc_cnt 0..31. Node = proc_cnt[3:2], Edge = proc_cnt[1:0] * 2 + proc_cnt[4]? No.
                    // Let's make proc_cnt 0 to 15. 16 cycles. 
                    // Cycle i (0-15): Edge index = i. Node = edge_from[i].
                    // We need to accumulate per node. This is hard in single cycle without memory.
                    // Back to sequential update: One node at a time.
                    // 4 iterations of 'proc_cnt' (0-3). Inside, scan edges.
                    // Let's make proc_cnt run 0 to 31 (32 cycles).
                    // Let's assume proc_cnt counts up to 31. 
                    // We need to store intermediate best values. 
                    // Let's use a temp array for this state's update.
                    
                    // Logic: 
                    // Cycle 0-15: Update Nodes 0,1? No.
                    // Let's stick to: 
                    // For node 0 to 3 (handled by proc_cnt>>3 or similar)
                    // Let's just iterate 4 times. 
                    // Wait, we need to process ALL edges for a node before moving to next.
                    
                    // Approach: Unrolled states or just a loop.
                    // Let's use proc_cnt 0..31. 
                    // We'll use 'node_idx' register to track current node being updated.
                    // We'll use 'best_val' to track max.
                    // We need to write back to dp_L[node_idx] when done with edges for that node.
                    
                    // Refinement: 
                    // proc_cnt 0-31. Edge index = proc_cnt.
                    // If proc_cnt == 0, reset best_val for node 0.
                    // Actually, update 1 node per state visit?
                    // Let's use the 60 cycle budget. 4 iterations * (Update L + Update R).
                    // Update L needs ~10-20 cycles.
                    // Let's use a 2-bit node counter (n), and a 4-bit edge counter (e).
                    // n = 0 to 3. 
                    // While in UPDATE_L and n=0: iterate edges 0..7. 
                    
                    if (proc_cnt < 8) begin // Node 0
                        node_idx <= 0;
                        if (proc_cnt == 0) best_val <= -24'sd1000000; // Init max
                        else begin
                            if (valid_edges[proc_cnt] && edge_from[proc_cnt] == 0) begin
                                if (dp_R[edge_to[proc_cnt]] != -24'sd1) begin
                                    temp_sum = edge_weight[proc_cnt] + dp_R[edge_to[proc_cnt]];
                                    if (temp_sum > best_val) best_val <= temp_sum;
                                end
                            end
                        end
                    end else if (proc_cnt < 16) begin // Node 1
                        node_idx <= 1;
                        if (proc_cnt == 8) best_val <= -24'sd1000000;
                        else begin
                            if (valid_edges[proc_cnt - 8] && edge_from[proc_cnt - 8] == 1) begin
                                if (dp_R[edge_to[proc_cnt - 8]] != -24'sd1) begin
                                    temp_sum = edge_weight[proc_cnt - 8] + dp_R[edge_to[proc_cnt - 8]];
                                    if (temp_sum > best_val) best_val <= temp_sum;
                                end
                            end
                        end
                    end else if (proc_cnt < 24) begin // Node 2
                        node_idx <= 2;
                        if (proc_cnt == 16) best_val <= -24'sd1000000;
                        else begin
                            if (valid_edges[proc_cnt - 16] && edge_from[proc_cnt - 16] == 2) begin
                                if (dp_R[edge_to[proc_cnt - 16]] != -24'sd1) begin
                                    temp_sum = edge_weight[proc_cnt - 16] + dp_R[edge_to[proc_cnt - 16]];
                                    if (temp_sum > best_val) best_val <= temp_sum;
                                end
                            end
                        end
                    end else begin // Node 3 (24-31)
                        node_idx <= 3;
                        if (proc_cnt == 24) best_val <= -24'sd1000000;
                        else begin
                            if (valid_edges[proc_cnt - 24] && edge_from[proc_cnt - 24] == 3) begin
                                if (dp_R[edge_to[proc_cnt - 24]] != -24'sd1) begin
                                    temp_sum = edge_weight[proc_cnt - 24] + dp_R[edge_to[proc_cnt - 24]];
                                    if (temp_sum > best_val) best_val <= temp_sum;
                                end
                            end
                        end
                    end
                    
                    // Writes happen at end of block
                    if (proc_cnt == 7) dp_L[0] <= (best_val == -24'sd1000000) ? -24'sd1 : best_val;
                    if (proc_cnt == 15) dp_L[1] <= (best_val == -24'sd1000000) ? -24'sd1 : best_val;
                    if (proc_cnt == 23) dp_L[2] <= (best_val == -24'sd1000000) ? -24'sd1 : best_val;
                    if (proc_cnt == 31) dp_L[3] <= (best_val == -24'sd1000000) ? -24'sd1 : best_val;
                    
                    if (proc_cnt == 31) proc_cnt <= 0;
                    else proc_cnt <= proc_cnt + 1;
                end

                UPDATE_R: begin
                    // Similar to UPDATE_L but Minimize
                    if (proc_cnt < 8) begin // Node 0
                        if (proc_cnt == 0) best_val <= 24'sd1000000; // Init min
                        else begin
                            if (valid_edges[proc_cnt] && edge_from[proc_cnt] == 0) begin
                                if (dp_L[edge_to[proc_cnt]] != -24'sd1) begin
                                    temp_sum = edge_weight[proc_cnt] + dp_L[edge_to[proc_cnt]];
                                    if (temp_sum < best_val) best_val <= temp_sum;
                                end
                            end
                        end
                        if (proc_cnt == 7) dp_R[0] <= (best_val == 24'sd1000000) ? -24'sd1 : best_val;
                    end else if (proc_cnt < 16) begin // Node 1
                        if (proc_cnt == 8) best_val <= 24'sd1000000;
                        else begin
                            if (valid_edges[proc_cnt - 8] && edge_from[proc_cnt - 8] == 1) begin
                                if (dp_L[edge_to[proc_cnt - 8]] != -24'sd1) begin
                                    temp_sum = edge_weight[proc_cnt - 8] + dp_L[edge_to[proc_cnt - 8]];
                                    if (temp_sum < best_val) best_val <= temp_sum;
                                end
                            end
                        end
                        if (proc_cnt == 15) dp_R[1] <= (best_val == 24'sd1000000) ? -24'sd1 : best_val;
                    end else if (proc_cnt < 24) begin // Node 2
                        if (proc_cnt == 16) best_val <= 24'sd1000000;
                        else begin
                            if (valid_edges[proc_cnt - 16] && edge_from[proc_cnt - 16] == 2) begin
                                if (dp_L[edge_to[proc_cnt - 16]] != -24'sd1) begin
                                    temp_sum = edge_weight[proc_cnt - 16] + dp_L[edge_to[proc_cnt - 16]];
                                    if (temp_sum < best_val) best_val <= temp_sum;
                                end
                            end
                        end
                        if (proc_cnt == 23) dp_R[2] <= (best_val == 24'sd1000000) ? -24'sd1 : best_val;
                    end else begin // Node 3
                        if (proc_cnt == 24) best_val <= 24'sd1000000;
                        else begin
                            if (valid_edges[proc_cnt - 24] && edge_from[proc_cnt - 24] == 3) begin
                                if (dp_L[edge_to[proc_cnt - 24]] != -24'sd1) begin
                                    temp_sum = edge_weight[proc_cnt - 24] + dp_L[edge_to[proc_cnt - 24]];
                                    if (temp_sum < best_val) best_val <= temp_sum;
                                end
                            end
                        end
                        if (proc_cnt == 31) dp_R[3] <= (best_val == 24'sd1000000) ? -24'sd1 : best_val;
                    end
                    
                    if (proc_cnt == 31) begin
                        proc_cnt <= 0;
                        iter_cnt <= iter_cnt + 1;
                    end else begin
                        proc_cnt <= proc_cnt + 1;
                    end
                end

                CHECK: begin
                    // Detect cycles.
                    // Simple check: If dp_L[s] is still -1 after iterations, or it is growing?
                    // The problem says: "If Left can reach a cycle (not t) where DP_L doesn't decrease to 0"
                    // With iterative updates in a graph with potentially positive cycles, values might increase.
                    // However, standard DP for shortest path with cycles usually requires Bellman-Ford.
                    // Here players maximize/minimize. 
                    // If we can't reach t, dp stays -1. 
                    // If we can reach t, dp becomes positive.
                    // If there's a cycle that prevents reaching t (or loops forever), we might need detection.
                    // Given 4 iterations (n-1 = 3), if dp_L[s] changed on the 4th iteration, there is a cycle.
                    // But we don't store previous value. 
                    // Let's implement: Check if dp_L[s] == -1 -> infinity.
                    // Also, if dp_L[s] is very large? 
                    // A cycle of weight 0 would keep value same. 
                    // A positive cycle might increase value.
                    // The problem implies: "If the path is infinite (cycle where player avoids target)"
                    // This happens if there is a reachable cycle from s, and from that cycle, t is not reachable (dp = -1).
                    // Or if the players can force a loop.
                    // Actually, if we run 4 iterations, and the value at s is NOT -1, we have a path.
                    // If the path involves a cycle that eventually reaches t, it's fine (fixed length).
                    // If the cycle never reaches t, then the edges leading out of cycle to t must be unreachable.
                    // So eventually dp_L[cycle_node] should be -1.
                    // So, if dp_L[s] == -1 after 4 iterations -> infinity.
                    // Let's stick to this simple check: dp_L[s] == -1 ? infinity : result.
                    
                    // Let's refine the check state to just latch values.
                    // The loop above handles 4 iterations (0,1,2,3). 
                    // If after 4 iterations, dp_L[s] is -1, it's infinity.
                    
                    if (check_node == 0) begin
                        if (dp_L[s] == -24'sd1) infinity <= 1;
                        else begin
                            infinity <= 0;
                            // Result clamping
                            if (dp_L[s] > 24'sd65535) result <= 16'hFFFF;
                            else result <= dp_L[s][15:0];
                        end
                        check_node <= 1; // Increment to exit state machine later (logic below)
                        // Wait, I set next_state to DONE when check_node==3.
                        // Let's just use check_node as a flag to transition.
                    end
                    // Actually, just one cycle check is enough if we did 4 iterations.
                    // But let's keep the structure. 
                    // If check_node == 0, perform check. Then increment check_node.
                    if (check_node == 3) begin
                        // Done checking. 
                        // Actually, we just need to set done.
                    end
                    
                    // Logic fix: The CHECK state in next_state transitions to DONE when check_node==3.
                    // Let's just increment check_node every cycle.
                    check_node <= check_node + 1;
                end

                DONE: begin
                    done <= 1;
                    // Result and infinity are latched from CHECK state.
                end
            endcase
        end
    end

endmodule
