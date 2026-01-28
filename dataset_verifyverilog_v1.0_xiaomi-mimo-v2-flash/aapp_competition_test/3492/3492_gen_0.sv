module max_flow_bipartite_matching (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [5:0] num_edges,
    input [63:0] edge_u,
    input [63:0] edge_v,
    input [63:0] capacity,
    output reg [3:0] max_flow,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BUILD = 3'd2;
    localparam [2:0] SEARCH = 3'd3;
    localparam [2:0] AUGMENT = 3'd4;
    localparam [2:0] UPDATE = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Registers and variables
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd4096;

    // Node and edge handling
    reg [3:0] current_edge;
    reg [3:0] u_node;
    reg [3:0] v_node;
    reg edge_valid;

    // Residual graph (16x16 matrix)
    // Using packed array for Icarus compatibility
    reg [255:0] residual_graph; // row major: node i's outgoing edges to j at bit (i*16 + j)
    reg [15:0] visited;
    reg [15:0] parent [0:15]; // BFS parent tracking
    reg [15:0] parent_reg; // Packed parent for current node
    
    // BFS Queue
    reg [3:0] queue [0:15];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg queue_empty;
    
    // Path tracking
    reg [3:0] path_node;
    reg [15:0] path_mask;
    
    // Augmentation
    reg [3:0] current_node;
    reg [3:0] prev_node;
    reg [3:0] edge_idx;

    // Counter for augmenting paths
    reg [3:0] augment_count;

    // DFS stack for alternative approach
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] dfs_current;
    reg [15:0] dfs_visited;
    reg [3:0] dfs_depth;
    reg [3:0] dfs_next_node;
    reg dfs_found;
    reg [3:0] path_buffer [0:15]; // Store path nodes

    // Helper signals for Icarus compatibility
    reg [7:0] bit_index;
    reg [7:0] bit_index2;
    reg has_augmented;

    // Edge extraction helper
    wire [3:0] extracted_u;
    wire [3:0] extracted_v;
    assign extracted_u = edge_u[(current_edge * 4) +: 4];
    assign extracted_v = edge_v[(current_edge * 4) +: 4];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_flow <= 4'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            current_edge <= 4'd0;
            residual_graph <= 256'd0;
            visited <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_empty <= 1'b1;
            path_node <= 4'd0;
            current_node <= 4'd0;
            prev_node <= 4'd0;
            edge_idx <= 4'd0;
            augment_count <= 4'd0;
            stack_ptr <= 4'd0;
            dfs_current <= 4'd0;
            dfs_visited <= 16'd0;
            dfs_depth <= 4'd0;
            dfs_found <= 1'b0;
            has_augmented <= 1'b0;
            path_mask <= 16'd0;
            u_node <= 4'd0;
            v_node <= 4'd0;
            // Initialize parent array
            for (int i = 0; i < 16; i = i + 1) begin
                parent[i] <= 16'd0;
            end
            // Initialize path buffer
            for (int i = 0; i < 16; i = i + 1) begin
                path_buffer[i] <= 4'd0;
            end
            // Initialize queue
            for (int i = 0; i < 16; i = i + 1) begin
                queue[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= INIT;
                        max_flow <= 4'd0;
                        augment_count <= 4'd0;
                        current_edge <= 4'd0;
                    end
                end

                INIT: begin
                    // Zero residual graph (256 bits)
                    residual_graph <= 256'd0;
                    state <= BUILD;
                    current_edge <= 4'd0;
                end

                BUILD: begin
                    if (current_edge < num_edges[3:0]) begin
                        u_node <= extracted_u;
                        v_node <= extracted_v;
                        state <= BUILD_EDGE;
                    end else begin
                        state <= SEARCH;
                        augment_count <= 4'd0;
                    end
                end

                BUILD_EDGE: begin
                    // Set forward edge capacity
                    bit_index <= {u_node[3:0], 4'd0} + v_node; // u*16 + v
                    residual_graph[bit_index] <= 1'b1;
                    current_edge <= current_edge + 4'd1;
                    state <= BUILD;
                end

                SEARCH: begin
                    // Find augmenting path using BFS (simplified Edmonds-Karp)
                    // Initialize BFS
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    queue_empty <= 1'b1;
                    visited <= 16'd0;
                    
                    // Check if source exists
                    if (augment_count >= num_nodes) begin
                        state <= DONE_STATE;
                    end else begin
                        // Start from source (node 0)
                        visited[0] <= 1'b1;
                        parent[0] <= 16'd0; // Self parent
                        queue[0] <= 4'd0;
                        queue_tail <= 4'd1;
                        queue_empty <= 1'b0;
                        state <= BFS_LOOP;
                    end
                    has_augmented <= 1'b0;
                end

                BFS_LOOP: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else if (!queue_empty && queue_head != queue_tail) begin
                        // Dequeue
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        if (queue_head + 4'd1 == queue_tail) begin
                            queue_empty <= 1'b1;
                        end
                        state <= CHECK_NEIGHBORS;
                        edge_idx <= 4'd0;
                    end else begin
                        // No augmenting path found
                        if (!has_augmented) begin
                            state <= DONE_STATE;
                        end else begin
                            state <= SEARCH;
                        end
                    end
                end

                CHECK_NEIGHBORS: begin
                    // Check all neighbors of current_node
                    if (edge_idx < 4'd16) begin
                        // Check if edge exists (residual capacity > 0)
                        bit_index <= {current_node[3:0], 4'd0} + edge_idx;
                        state <= CHECK_EDGE;
                    end else begin
                        state <= BFS_LOOP;
                    end
                end

                CHECK_EDGE: begin
                    // Check if edge to 'edge_idx' exists and node not visited
                    if (residual_graph[bit_index] && !visited[edge_idx]) begin
                        visited[edge_idx] <= 1'b1;
                        parent[edge_idx] <= {12'd0, current_node}; // Store parent
                        queue[queue_tail] <= edge_idx;
                        queue_tail <= queue_tail + 4'd1;
                        queue_empty <= 1'b0;
                        
                        // Check if we reached sink (node 15)
                        if (edge_idx == 4'd15) begin
                            state <= FOUND_PATH;
                        end else begin
                            edge_idx <= edge_idx + 4'd1;
                            state <= CHECK_NEIGHBORS;
                        end
                    end else begin
                        edge_idx <= edge_idx + 4'd1;
                        state <= CHECK_NEIGHBORS;
                    end
                end

                FOUND_PATH: begin
                    // Reconstruct path from sink to source
                    has_augmented <= 1'b1;
                    path_node <= 4'd15; // Start from sink
                    state <= RECONSTRUCT_PATH;
                end

                RECONSTRUCT_PATH: begin
                    // Get parent of current node
                    prev_node <= parent[path_node][3:0];
                    // Find the edge index for this pair
                    current_node <= prev_node;
                    edge_idx <= path_node;
                    state <= UPDATE_RESIDUAL;
                end

                UPDATE_RESIDUAL: begin
                    // Remove forward edge, add reverse edge
                    // Forward: prev_node -> path_node
                    bit_index <= {current_node[3:0], 4'd0} + edge_idx;
                    residual_graph[bit_index] <= 1'b0;
                    // Reverse: path_node -> prev_node
                    bit_index2 <= {edge_idx[3:0], 4'd0} + current_node;
                    residual_graph[bit_index2] <= 1'b1;
                    
                    if (prev_node == 4'd0) begin
                        // Reached source
                        state <= UPDATE_FLOW;
                    end else begin
                        path_node <= prev_node;
                        state <= RECONSTRUCT_PATH;
                    end
                end

                UPDATE_FLOW: begin
                    // Increment flow counter
                    max_flow <= max_flow + 4'd1;
                    augment_count <= augment_count + 4'd1;
                    state <= SEARCH;
                    cycle_count <= 16'd0; // Reset cycle counter for next search
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule