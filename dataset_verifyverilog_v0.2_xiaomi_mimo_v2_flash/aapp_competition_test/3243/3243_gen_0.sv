module network_merger (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_nodes,
    input [7:0] k,
    input [63:0] edge_mask,
    input [63:0] capacity_mask,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PARSE = 3'b001;
    localparam FLOYD_INIT = 3'b010;
    localparam FLOYD_ITER = 3'b011;
    localparam COUNT_COMPONENTS = 3'b100;
    localparam CHECK_CONDITIONS = 3'b101;
    localparam FINISH = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal Registers
    reg [63:0] reachability;       // Flattened 8x8 matrix (bit [u*8 + v])
    reg [63:0] next_reachability;
    reg [7:0] visited_nodes;       // Bitmask for DFS components counting
    reg [7:0] node_queue;          // Current nodes being explored in DFS
    reg [7:0] component_count;
    reg [7:0] k_reg;               // Registered k
    reg [7:0] num_nodes_reg;       // Registered num_nodes
    
    // Iteration counters
    reg [2:0] k_idx;               // Floyd-Warshall pivot node index
    reg [2:0] i_idx;               // Row index
    reg [2:0] j_idx;               // Column index
    reg [2:0] step;                // Internal step counter for loops

    // Helper wires for logic
    wire [7:0] i_bit = 8'b00000001 << i_idx;
    wire [7:0] j_bit = 8'b00000001 << j_idx;
    wire [7:0] k_bit = 8'b00000001 << k_idx;

    // Capacity Parsing Logic: Check if any node lacks capacity (capacity < 2)
    // Capacity mask bit [4*i +: 4]. If < 2, value is 0 or 1, meaning LSB is 0 (00 or 01).
    // If >= 2, value is 2 (10) or more.
    wire insufficient_capacity;
    assign insufficient_capacity = 
        (num_nodes_reg > 0 && capacity_mask[3:0] < 2) ||
        (num_nodes_reg > 1 && capacity_mask[7:4] < 2) ||
        (num_nodes_reg > 2 && capacity_mask[11:8] < 2) ||
        (num_nodes_reg > 3 && capacity_mask[15:12] < 2) ||
        (num_nodes_reg > 4 && capacity_mask[19:16] < 2) ||
        (num_nodes_reg > 5 && capacity_mask[23:20] < 2) ||
        (num_nodes_reg > 6 && capacity_mask[27:24] < 2) ||
        (num_nodes_reg > 7 && capacity_mask[31:28] < 2);

    // Sequential State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            
            // Registers update based on state
            case (state)
                IDLE: begin
                    if (start) begin
                        k_reg <= k;
                        num_nodes_reg <= num_nodes;
                        done <= 0;
                    end
                end
                FLOYD_INIT: begin
                    // Initialize reachability: Edges + Self
                    if (step == 0) begin
                        reachability <= edge_mask;
                        // Set diagonals (self-loops) for all potential nodes 0-7
                        // Note: If num_nodes is small, we still compute for all 8, 
                        // but component count limits it later.
                        reachability[0] <= 1; reachability[9] <= 1;
                        reachability[18] <= 1; reachability[27] <= 1;
                        reachability[36] <= 1; reachability[45] <= 1;
                        reachability[54] <= 1; reachability[63] <= 1;
                    end
                end
                FLOYD_ITER: begin
                    // Transitive closure: R[i][j] = R[i][j] | (R[i][k] & R[k][j])
                    // Optimization: Unroll implicitly or use intermediate check
                    // For synthesis, we update 'reachability' directly if condition met
                    if (reachability[i_idx*8 + j_idx] == 0 && 
                        reachability[i_idx*8 + k_idx] == 1 && 
                        reachability[k_idx*8 + j_idx] == 1) begin
                        reachability[i_idx*8 + j_idx] <= 1;
                    end
                    // Handle symmetry for undirected graph (optional but good for robustness)
                    if (reachability[j_idx*8 + i_idx] == 0 && 
                        reachability[j_idx*8 + k_idx] == 1 && 
                        reachability[k_idx*8 + i_idx] == 1) begin
                        reachability[j_idx*8 + i_idx] <= 1;
                    end
                end
                COUNT_COMPONENTS: begin
                    if (step == 0) begin // Initialize first node exploration
                        visited_nodes <= 0;
                        component_count <= 0;
                    end else if (step == 1) begin // Assign queue if needed
                        if (node_queue == 0 && visited_nodes != 0) begin
                            // Should theoretically not happen if logic is correct, 
                            // but acts as safety to start next component.
                        end
                    end else if (step == 2) begin // Mark reachable nodes as visited
                        // node_queue holds current frontier. New queue = reachable from queue not visited
                        // Logic handled in combinational block below to update 'node_queue' in state transition
                        visited_nodes <= visited_nodes | node_queue;
                    end else if (step == 3) begin // Increment counter
                         component_count <= component_count + 1;
                    end
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = PARSE;
            
            PARSE: begin
                if (num_nodes_reg < 2) next_state = DONE; // Trivially merged or no nodes
                else if (insufficient_capacity) next_state = DONE; // Impossible without capacity edits (not supported)
                else next_state = FLOYD_INIT;
            end

            FLOYD_INIT: next_state = FLOYD_ITER;

            FLOYD_ITER: begin
                // Loop structure: k (0..7), i (0..7), j (0..7)
                // Since 'step' is a coarse counter, we use index increments
                // We process all combinations for the current 'k_idx'
                if (j_idx < 7 || i_idx < 7 || k_idx < 7) next_state = FLOYD_ITER;
                else next_state = COUNT_COMPONENTS;
            end

            COUNT_COMPONENTS: begin
                // DFS Logic: While there are unvisited nodes
                // If node_queue is empty and there are unvisited nodes < num_nodes_reg, find new start
                // If node_queue is not empty, expand
                // If all nodes visited (based on num_nodes_reg), go to CHECK
                // We simulate loop with steps
                if (step == 4) next_state = COUNT_COMPONENTS; // Loop back
                else if (step == 5) next_state = CHECK_CONDITIONS; // Done counting
                else next_state = COUNT_COMPONENTS;
            end

            CHECK_CONDITIONS: next_state = DONE;
            DONE: next_state = IDLE; // Auto-reset or wait for external reset
        endcase
    end

    // Combinational Logic for Iterations and Data Path
    always @(*) begin
        // Defaults
        next_reachability = reachability;
        
        // Step/Counter management
        // Logic for FLOYD_ITER loop control
        if (state == FLOYD_ITER) begin
            // If we just entered this state or finished a cycle, advance indices
            // (Handled in sequential block via 'step' or direct checking)
        end
    end

    // Separate block for state-specific auxiliary logic (Counters, Queue)
    reg [2:0] next_step;
    reg [2:0] next_k_idx;
    reg [2:0] next_i_idx;
    reg [2:0] next_j_idx;
    reg [7:0] next_node_queue;
    reg [7:0] next_component_count;

    always @(*) begin
        next_step = step;
        next_k_idx = k_idx;
        next_i_idx = i_idx;
        next_j_idx = j_idx;
        next_node_queue = node_queue;
        next_component_count = component_count;

        case (state)
            IDLE: begin
                next_step = 0;
                next_k_idx = 0;
                next_i_idx = 0;
                next_j_idx = 0;
                next_node_queue = 0;
            end
            PARSE: begin
                // Just transition
            end
            FLOYD_INIT: begin
                next_step = 0;
            end
            FLOYD_ITER: begin
                // Advance indices logic
                // We iterate k (0..7), inside k we iterate i (0..7), j (0..7)
                next_j_idx = j_idx + 1;
                if (next_j_idx == 8) begin
                    next_j_idx = 0;
                    next_i_idx = i_idx + 1;
                    if (next_i_idx == 8) begin
                        next_i_idx = 0;
                        next_k_idx = k_idx + 1;
                    end
                end
            end
            COUNT_COMPONENTS: begin
                // DFS Logic
                // If step 0: Init done, move to 1
                if (step == 0) next_step = 1;
                
                // Step 1: If node_queue is empty, find a new start node not in visited_nodes
                else if (step == 1) begin
                    if (num_nodes_reg == 0) begin
                         next_step = 5; // Done
                    end else if (node_queue == 0) begin
                        // Find start node
                        if (visited_nodes == 0) next_node_queue = 8'h01; // Node 0
                        else if (num_nodes_reg > 1 && !visited_nodes[1]) next_node_queue = 8'h02;
                        else if (num_nodes_reg > 2 && !visited_nodes[2]) next_node_queue = 8'h04;
                        else if (num_nodes_reg > 3 && !visited_nodes[3]) next_node_queue = 8'h08;
                        else if (num_nodes_reg > 4 && !visited_nodes[4]) next_node_queue = 8'h10;
                        else if (num_nodes_reg > 5 && !visited_nodes[5]) next_node_queue = 8'h20;
                        else if (num_nodes_reg > 6 && !visited_nodes[6]) next_node_queue = 8'h40;
                        else if (num_nodes_reg > 7 && !visited_nodes[7]) next_node_queue = 8'h80;
                        else next_step = 5; // All visited
                        
                        if (next_node_queue != 0) next_step = 2;
                    end else begin
                        next_step = 2;
                    end
                end

                // Step 2: Expand current queue
                // New queue = (Reachability from current queue) AND NOT visited
                else if (step == 2) begin
                    next_node_queue = 0;
                    // Unrolled expansion for all nodes in queue
                    if (node_queue[0]) next_node_queue = next_node_queue | reachability[7:0];
                    if (node_queue[1]) next_node_queue = next_node_queue | reachability[15:8];
                    if (node_queue[2]) next_node_queue = next_node_queue | reachability[23:16];
                    if (node_queue[3]) next_node_queue = next_node_queue | reachability[31:24];
                    if (node_queue[4]) next_node_queue = next_node_queue | reachability[39:32];
                    if (node_queue[5]) next_node_queue = next_node_queue | reachability[47:40];
                    if (node_queue[6]) next_node_queue = next_node_queue | reachability[55:48];
                    if (node_queue[7]) next_node_queue = next_node_queue | reachability[63:56];
                    
                    // Mask to valid nodes only (0 to num_nodes_reg-1)
                    // Create mask: e.g., if num_nodes=3, mask is 00000111
                    reg [7:0] valid_mask;
                    case(num_nodes_reg)
                        1: valid_mask = 8'h01;
                        2: valid_mask = 8'h03;
                        3: valid_mask = 8'h07;
                        4: valid_mask = 8'h0F;
                        5: valid_mask = 8'h1F;
                        6: valid_mask = 8'h3F;
                        7: valid_mask = 8'h7F;
                        8: valid_mask = 8'hFF;
                        default: valid_mask = 8'hFF;
                    endcase
                    next_node_queue = next_node_queue & valid_mask;
                    
                    // Remove already visited
                    next_node_queue = next_node_queue & ~visited_nodes;
                    
                    next_step = 3;
                end
                
                // Step 3: Mark visited (handled in sequential)
                else if (step == 3) begin
                    next_step = 4;
                end
                
                // Step 4: Loop Check
                else if (step == 4) begin
                    // If queue is not empty, repeat step 2 (expand more)
                    if (node_queue != 0) begin
                        next_step = 2;
                    end else begin
                        // Queue empty, check if all nodes visited
                        // If visited_nodes has all bits 0 to num_nodes-1 set
                        // We increment component count here (done in seq block step 3)
                        // Then go back to step 1 to find next start
                        // Check if done
                        reg all_visited;
                        all_visited = 1;
                        if (num_nodes_reg > 0 && !visited_nodes[0]) all_visited = 0;
                        if (num_nodes_reg > 1 && !visited_nodes[1]) all_visited = 0;
                        if (num_nodes_reg > 2 && !visited_nodes[2]) all_visited = 0;
                        if (num_nodes_reg > 3 && !visited_nodes[3]) all_visited = 0;
                        if (num_nodes_reg > 4 && !visited_nodes[4]) all_visited = 0;
                        if (num_nodes_reg > 5 && !visited_nodes[5]) all_visited = 0;
                        if (num_nodes_reg > 6 && !visited_nodes[6]) all_visited = 0;
                        if (num_nodes_reg > 7 && !visited_nodes[7]) all_visited = 0;
                        
                        if (all_visited) next_step = 5;
                        else next_step = 1;
                    end
                end
            end
            CHECK_CONDITIONS: begin
                // Just transition
            end
        endcase
    end

    // Sequential for counters and aux regs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step <= 0;
            k_idx <= 0;
            i_idx <= 0;
            j_idx <= 0;
            node_queue <= 0;
            component_count <= 0;
        end else begin
            step <= next_step;
            k_idx <= next_k_idx;
            i_idx <= next_i_idx;
            j_idx <= next_j_idx;
            node_queue <= next_node_queue;
            component_count <= next_component_count;
        end
    end

    // Result Calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
        end else if (state == CHECK_CONDITIONS) begin
            // Strict check: if k < components - 1, NO. Else YES.
            // Note: component_count is final count.
            // Result logic:
            // 1. If capacity insufficient -> 0 (handled in PARSE transition to DONE with result=0?)
            //    Actually, we set result=0 in DONE. Let's set it explicitly.
            
            if (insufficient_capacity) begin
                result <= 0;
            end else if (num_nodes_reg < 2) begin
                result <= 1; // 0 or 1 node is merged
            end else begin
                // Required edges to merge: components - 1
                // components = component_count
                // Check if k_reg >= component_count - 1
                // Handle component_count == 0 (shouldn't happen) or 1
                if (component_count <= 1) result <= 1;
                else begin
                    // k >= count - 1
                    // Since k is [7:0], count is [7:0]
                    if (k_reg >= (component_count - 1)) result <= 1;
                    else result <= 0;
                end
            end
        end else if (state == IDLE && start) begin
            // Speculative reset of result before calculation starts (optional)
            // result <= 0;
        end
    end

endmodule
