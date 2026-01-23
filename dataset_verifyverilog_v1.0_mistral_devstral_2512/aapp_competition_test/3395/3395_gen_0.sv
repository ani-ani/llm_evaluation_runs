module resource_claim (
    input clk,
    input rst_n,
    input start,
    
    // Graph topology - 16 nodes, each with up to 4 neighbors
    input [3:0] node_count,           // Number of nodes (1-16)
    input [3:0] iron_count,           // Number of iron ore nodes (1-4)
    input [3:0] coal_count,           // Number of coal nodes (1-4)
    
    // Resource locations
    input [3:0] iron_nodes [0:3],     // IDs of iron ore cells
    input [3:0] coal_nodes [0:3],     // IDs of coal cells
    
    // Graph connectivity - adjacency matrix representation
    input [15:0] adjacency [0:15],    // Each row: bit i=1 means edge to node i
    
    output reg [7:0] result,          // Minimal settlers needed
    output reg done,                  // Computation complete
    output reg impossible             // No solution possible
);

// State machine
localparam [2:0] IDLE = 3'd0;
localparam [2:0] BFS_IRON = 3'd1;
localparam [2:0] BFS_COAL = 3'd2;
localparam [2:0] COMPUTE = 3'd3;
localparam [2:0] DONE = 3'd4;

reg [2:0] state;
reg [3:0] queue [0:15];  // BFS queue
reg [4:0] q_head, q_tail;
reg [7:0] dist_iron [0:15];  // Distance from node 1 to each node (for iron BFS)
reg [7:0] dist_coal [0:15];  // Distance from node 1 to each node (for coal BFS)
reg [15:0] visited;
reg [3:0] current_node;
reg [3:0] target_idx;
reg [7:0] min_settlers;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        impossible <= 1'b0;
        result <= 8'd0;
        q_head <= 5'd0;
        q_tail <= 5'd0;
        for (i = 0; i < 16; i = i + 1) begin
            dist_iron[i] <= 8'd255;
            dist_coal[i] <= 8'd255;
        end
        visited <= 16'd0;
        min_settlers <= 8'd255;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    // Initialize BFS for iron
                    for (i = 0; i < 16; i = i + 1) begin
                        dist_iron[i] <= 8'd255;
                        dist_coal[i] <= 8'd255;
                    end
                    dist_iron[0] <= 8'd0;  // Node 1 is index 0
                    dist_coal[0] <= 8'd0;
                    visited <= 16'd0;
                    q_head <= 5'd0;
                    q_tail <= 5'd0;
                    target_idx <= 4'd0;
                    state <= BFS_IRON;
                    impossible <= 1'b0;
                end
            end
            
            BFS_IRON: begin
                // Run BFS to find distances to all iron nodes
                if (q_head < q_tail) begin
                    current_node <= queue[q_head];
                    q_head <= q_head + 5'd1;
                end else if (q_head == q_tail && q_head == 5'd0) begin
                    // First node - add node 0 to queue
                    queue[0] <= 4'd0;
                    q_tail <= 5'd1;
                end else if (dist_iron[target_idx] != 8'd255 && target_idx < iron_count) begin
                    // Found current iron node, move to next
                    target_idx <= target_idx + 4'd1;
                end else if (target_idx < iron_count) begin
                    // Check if current iron node reached
                    if (dist_iron[iron_nodes[target_idx]] != 8'd255) begin
                        target_idx <= target_idx + 4'd1;
                    end else begin
                        // Add neighbors to queue
                        for (i = 0; i < 16; i = i + 1) begin
                            if (adjacency[current_node][i] && !visited[i] && dist_iron[i] == 8'd255) begin
                                queue[q_tail] <= i;
                                q_tail <= q_tail + 5'd1;
                                dist_iron[i] <= dist_iron[current_node] + 8'd1;
                                visited[i] <= 1'b1;
                            end
                        end
                    end
                end else if (target_idx >= iron_count) begin
                    // Iron BFS complete, start coal BFS
                    q_head <= 5'd0;
                    q_tail <= 5'd0;
                    visited <= 16'd0;
                    target_idx <= 4'd0;
                    state <= BFS_COAL;
                end
            end
            
            BFS_COAL: begin
                // Run BFS for coal nodes
                if (q_head < q_tail) begin
                    current_node <= queue[q_head];
                    q_head <= q_head + 5'd1;
                end else if (q_head == q_tail && q_head == 5'd0) begin
                    queue[0] <= 4'd0;
                    q_tail <= 5'd1;
                end else if (target_idx < coal_count) begin
                    if (dist_coal[coal_nodes[target_idx]] != 8'd255) begin
                        target_idx <= target_idx + 4'd1;
                    end else begin
                        for (i = 0; i < 16; i = i + 1) begin
                            if (adjacency[current_node][i] && !visited[i] && dist_coal[i] == 8'd255) begin
                                queue[q_tail] <= i;
                                q_tail <= q_tail + 5'd1;
                                dist_coal[i] <= dist_coal[current_node] + 8'd1;
                                visited[i] <= 1'b1;
                            end
                        end
                    end
                end else begin
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Find minimal settlers by combining paths
                min_settlers <= 8'd255;
                
                // Check all combinations of iron and coal
                for (i = 0; i < 4; i = i + 1) begin
                    if (i < iron_count && dist_iron[iron_nodes[i]] != 8'd255) begin
                        integer j;
                        for (j = 0; j < 4; j = j + 1) begin
                            if (j < coal_count && dist_coal[coal_nodes[j]] != 8'd255) begin
                                // Total settlers = iron_dist + coal_dist - 1 (shared starting point)
                                reg [7:0] total;
                                total = dist_iron[iron_nodes[i]] + dist_coal[coal_nodes[j]] - 8'd1;
                                if (total < min_settlers) begin
                                    min_settlers <= total;
                                end
                            end
                        end
                    end
                end
                
                if (min_settlers == 8'd255) begin
                    impossible <= 1'b1;
                end else begin
                    result <= min_settlers;
                end
                state <= DONE;
            end
            
            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule