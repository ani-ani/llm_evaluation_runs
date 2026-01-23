module max_flow_solver (
    input clk,
    input rst_n,
    input start,
    input [1:0] source,         // source node (0-3)
    input [1:0] sink,           // sink node (0-3)
    input [1:0] num_nodes,      // number of nodes (1-4)
    input [5:0] edge_count,     // number of edges (0-63)
    input [15:0] capacity [0:3][0:3], // capacity matrix
    output reg [15:0] max_flow, // maximum flow value
    output reg [5:0] used_edges,// number of edges with flow > 0
    output reg [1:0] out_u,     // output edge source
    output reg [1:0] out_v,     // output edge destination
    output reg [15:0] out_flow, // flow on current edge
    output reg out_valid,       // high when output edge is valid
    output reg done            // high when computation complete
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam BFS_SEARCH = 3'b010;
    localparam AUGMENT = 3'b011;
    localparam OUTPUT = 3'b100;
    localparam DONE = 3'b101;

    // Registers for state
    reg [2:0] current_state;
    reg [2:0] next_state;

    // Residual capacity matrix (4x4, 16-bit)
    reg [15:0] residual [0:3][0:3];
    
    // Original capacity matrix storage
    reg [15:0] orig_capacity [0:3][0:3];

    // Parent array for BFS (stores parent node index for each node)
    reg [1:0] parent [0:3];
    
    // Visited array for BFS
    reg visited [0:3];
    
    // BFS Queue
    reg [1:0] queue [0:3];
    reg [1:0] queue_head;  // index to dequeue
    reg [1:0] queue_tail;  // index to enqueue
    reg [1:0] queue_count; // number of elements
    
    // Path reconstruction buffer
    reg [1:0] path_nodes [0:3]; // stores nodes in path
    reg [1:0] path_length;
    reg [1:0] path_idx;
    
    // Bottleneck capacity for augmentation
    reg [15:0] bottleneck;
    
    // Current node for BFS iteration
    reg [1:0] current_node;
    reg [1:0] neighbor_idx;
    
    // Output iteration variables
    reg [1:0] output_u;
    reg [1:0] output_v;
    reg [5:0] output_count;
    
    // Temporary registers for calculation
    reg [15:0] flow_value;
    reg [15:0] min_val;
    
    // Counter for delay cycles
    reg [7:0] cycle_counter;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            
            INIT: begin
                // Initialize residual graph
                next_state = BFS_SEARCH;
            end
            
            BFS_SEARCH: begin
                // Check if we found sink or queue is empty
                if (queue_count == 0 && queue_head == queue_tail) begin
                    // No augmenting path, go to output
                    next_state = OUTPUT;
                end else if (current_node == sink && visited[sink]) begin
                    // Found path to sink
                    next_state = AUGMENT;
                end else begin
                    next_state = BFS_SEARCH;
                end
            end
            
            AUGMENT: begin
                // Augmentation complete
                next_state = BFS_SEARCH;
            end
            
            OUTPUT: begin
                // Continue until all edges processed
                if (output_count >= num_nodes * num_nodes) begin
                    next_state = DONE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            DONE: begin
                // Stay in done state
                next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Main datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            max_flow <= 16'b0;
            used_edges <= 6'b0;
            out_u <= 2'b0;
            out_v <= 2'b0;
            out_flow <= 16'b0;
            out_valid <= 1'b0;
            done <= 1'b0;
            
            // Reset internal state
            queue_head <= 2'b0;
            queue_tail <= 2'b0;
            queue_count <= 2'b0;
            current_node <= 2'b0;
            neighbor_idx <= 2'b0;
            path_length <= 2'b0;
            path_idx <= 2'b0;
            output_count <= 6'b0;
            bottleneck <= 16'b0;
            cycle_counter <= 8'b0;
            
            // Clear arrays
            begin : reset_arrays
                integer i, j;
                for (i = 0; i < 4; i = i + 1) begin
                    parent[i] <= 2'b0;
                    visited[i] <= 1'b0;
                    queue[i] <= 2'b0;
                    path_nodes[i] <= 2'b0;
                    for (j = 0; j < 4; j = j + 1) begin
                        residual[i][j] <= 16'b0;
                        orig_capacity[i][j] <= 16'b0;
                    end
                end
            end
        end else begin
            case (current_state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        max_flow <= 16'b0;
                        used_edges <= 6'b0;
                        output_count <= 6'b0;
                    end
                end
                
                INIT: begin
                    // Initialize residual graph from capacity matrix
                    // Also store original capacities
                    begin : init_loop
                        integer i, j;
                        for (i = 0; i < 4; i = i + 1) begin
                            for (j = 0; j < 4; j = j + 1) begin
                                if (i < num_nodes && j < num_nodes) begin
                                    residual[i][j] <= capacity[i][j];
                                    orig_capacity[i][j] <= capacity[i][j];
                                end else begin
                                    residual[i][j] <= 16'b0;
                                    orig_capacity[i][j] <= 16'b0;
                                end
                            end
                        end
                    end
                    
                    // Reset BFS structures
                    queue_head <= 2'b0;
                    queue_tail <= 2'b0;
                    queue_count <= 2'b0;
                    visited[0] <= 1'b0;
                    visited[1] <= 1'b0;
                    visited[2] <= 1'b0;
                    visited[3] <= 1'b0;
                    
                    current_node <= source;
                    neighbor_idx <= 2'b0;
                end
                
                BFS_SEARCH: begin
                    out_valid <= 1'b0;
                    
                    // Initialize BFS from source if queue empty
                    if (queue_count == 2'b0 && !visited[source]) begin
                        visited[source] <= 1'b1;
                        parent[source] <= source; // source parent is itself
                        queue[queue_tail] <= source;
                        queue_tail <= queue_tail + 1'b1;
                        queue_count <= queue_count + 1'b1;
                        current_node <= source;
                    end else if (queue_count > 0) begin
                        // Dequeue current node
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 1'b1;
                        queue_count <= queue_count - 1'b1;
                        
                        // Start checking neighbors
                        neighbor_idx <= 2'b0;
                    end else if (current_node == sink && visited[sink]) begin
                        // Path found, will transition to AUGMENT
                        // Reconstruct path
                        begin : reconstruct_path
                            reg [1:0] temp_node;
                            integer idx;
                            temp_node = sink;
                            idx = 0;
                            while (temp_node != source && idx < 4) begin
                                path_nodes[idx] <= temp_node;
                                temp_node = parent[temp_node];
                                idx = idx + 1;
                            end
                            path_nodes[idx] <= source;
                            path_length <= idx + 1'b1;
                            path_idx <= 2'b0;
                        end
                        
                        // Find bottleneck
                        bottleneck <= 16'hFFFF; // Max value
                        path_idx <= 2'b0;
                    end
                    
                    // Process neighbors if we have a current node
                    if (queue_count > 0 && neighbor_idx < num_nodes) begin
                        // Check if there's residual capacity and neighbor not visited
                        if (residual[current_node][neighbor_idx] > 0 && !visited[neighbor_idx]) begin
                            // Add to queue
                            visited[neighbor_idx] <= 1'b1;
                            parent[neighbor_idx] <= current_node;
                            queue[queue_tail] <= neighbor_idx;
                            queue_tail <= queue_tail + 1'b1;
                            queue_count <= queue_count + 1'b1;
                        end
                        neighbor_idx <= neighbor_idx + 1'b1;
                    end
                end
                
                AUGMENT: begin
                    // Update residual capacities along the path
                    if (path_idx < path_length - 1) begin
                        reg [1:0] u, v;
                        u = path_nodes[path_idx + 1];
                        v = path_nodes[path_idx];
                        
                        // Subtract flow from forward edge
                        residual[u][v] <= residual[u][v] - bottleneck;
                        // Add flow to backward edge
                        residual[v][u] <= residual[v][u] + bottleneck;
                        
                        path_idx <= path_idx + 1'b1;
                    end else begin
                        // Augmentation complete, update max_flow
                        max_flow <= max_flow + bottleneck;
                        
                        // Reset BFS for next iteration
                        queue_head <= 2'b0;
                        queue_tail <= 2'b0;
                        queue_count <= 2'b0;
                        current_node <= source;
                        neighbor_idx <= 2'b0;
                        
                        // Reset visited
                        visited[0] <= 1'b0;
                        visited[1] <= 1'b0;
                        visited[2] <= 1'b0;
                        visited[3] <= 1'b0;
                    end
                    
                    // Calculate bottleneck during first iteration of AUGMENT
                    if (path_idx == 0) begin
                        begin : calc_bottleneck
                            reg [15:0] min_cap;
                            reg [15:0] edge_cap;
                            integer i;
                            min_cap = 16'hFFFF;
                            for (i = 0; i < 3; i = i + 1) begin
                                if (i < path_length - 1) begin
                                    edge_cap = residual[path_nodes[i + 1]][path_nodes[i]];
                                    if (edge_cap < min_cap)
                                        min_cap = edge_cap;
                                end
                            end
                            bottleneck <= min_cap;
                        end
                    end
                end
                
                OUTPUT: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    
                    // Iterate through all possible edges
                    if (output_count < num_nodes * num_nodes) begin
                        output_u <= output_count / num_nodes;
                        output_v <= output_count % num_nodes;
                        
                        // Check if edge has flow
                        if (output_count / num_nodes < num_nodes && output_count % num_nodes < num_nodes) begin
                            reg [1:0] u, v;
                            reg [15:0] orig_cap, res_cap, flow_val;
                            u = output_count / num_nodes;
                            v = output_count % num_nodes;
                            orig_cap = orig_capacity[u][v];
                            res_cap = residual[u][v];
                            
                            if (orig_cap > res_cap) begin
                                flow_val = orig_cap - res_cap;
                                out_u <= u;
                                out_v <= v;
                                out_flow <= flow_val;
                                out_valid <= 1'b1;
                                used_edges <= used_edges + 1'b1;
                            end
                        end
                        
                        output_count <= output_count + 1'b1;
                    end
                end
                
                DONE: begin
                    out_valid <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
