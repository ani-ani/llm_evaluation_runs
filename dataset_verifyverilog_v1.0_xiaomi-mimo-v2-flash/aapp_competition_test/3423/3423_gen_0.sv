module topological_sorter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [9:0] edge_valid,
    input wire [3:0] edge_from,
    input wire [3:0] edge_to,
    input wire edge_wr,
    output reg [3:0] result_idx,
    output reg result_valid,
    output reg done,
    output reg cycle_detected,
    output reg result_empty
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD_EDGES  = 3'd1;
    localparam [2:0] SORT        = 3'd2;
    localparam [2:0] OUTPUT      = 3'd3;
    localparam [2:0] FINISH      = 3'd4;

    // Adjacency matrix: adj[i][j] means dependency from i to j
    reg [9:0] adj [0:9];  // adj[row][col:col] - each row has bits for columns
    
    // In-degree counters
    reg [3:0] in_degree [0:9];  // 4-bit counter, max 20 dependencies
    
    // Queue for Kahn's algorithm
    reg [3:0] queue [0:9];  // Stores node indices
    reg [3:0] queue_head;   // Index for head
    reg [3:0] queue_tail;   // Index for tail
    
    // Result storage
    reg [3:0] result [0:9];
    reg [3:0] result_count;  // Number of nodes in result
    reg [3:0] output_count;  // Number of nodes output
    
    // Working registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] node_idx;        // For iteration
    reg [3:0] temp_node;       // Temporary node storage
    reg [3:0] nodes_processed; // Count of nodes processed in sorting
    reg [3:0] cycle_count;     // Timeout prevention
    
    // Edge loading state
    reg [9:0] edge_processed;  // Track which edges have been loaded
    
    integer i, j;  // Loop variables

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result_idx <= 4'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            cycle_detected <= 1'b0;
            result_empty <= 1'b0;
            
            // Initialize adjacency matrix
            for (i = 0; i < 10; i = i + 1) begin
                adj[i] <= 10'd0;
            end
            
            // Initialize in-degree
            for (i = 0; i < 10; i = i + 1) begin
                in_degree[i] <= 4'd0;
            end
            
            // Initialize queue
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                queue[i] <= 4'd0;
            end
            
            // Initialize result
            result_count <= 4'd0;
            output_count <= 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                result[i] <= 4'd0;
            end
            
            // Reset working registers
            node_idx <= 4'd0;
            temp_node <= 4'd0;
            nodes_processed <= 4'd0;
            cycle_count <= 4'd0;
            edge_processed <= 10'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    // Clear flags
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    cycle_detected <= 1'b0;
                    result_empty <= 1'b0;
                    
                    if (start) begin
                        // Start new operation
                        state <= LOAD_EDGES;
                        edge_processed <= 10'd0;
                        
                        // Clear adjacency and in-degree
                        for (i = 0; i < 10; i = i + 1) begin
                            adj[i] <= 10'd0;
                            in_degree[i] <= 4'd0;
                        end
                    end
                end
                
                LOAD_EDGES: begin
                    if (edge_wr) begin
                        // Process edge write - update adjacency matrix and in-degree
                        for (i = 0; i < 10; i = i + 1) begin
                            if (edge_valid[i]) begin
                                // Set adjacency bit: from -> to
                                // adj[edge_from][edge_to] = 1
                                if (edge_from < 10 && edge_to < 10) begin
                                    adj[edge_from][edge_to] <= 1'b1;
                                    in_degree[edge_to] <= in_degree[edge_to] + 4'd1;
                                end
                            end
                        end
                        
                        // Mark this edge as processed
                        for (i = 0; i < 10; i = i + 1) begin
                            if (edge_valid[i]) begin
                                edge_processed[i] <= 1'b1;
                            end
                        end
                    end
                    
                    // Transition to SORT when all edges are loaded or user signals done
                    // For simplicity, wait for a condition or timeout
                    // In real design, would need explicit "edges_complete" signal
                    // Here we transition after small timeout for demo
                    if (edge_wr == 1'b0) begin
                        // Wait a bit, then proceed
                        if (cycle_count >= 4'd5) begin
                            state <= SORT;
                            cycle_count <= 4'd0;
                            
                            // Initialize Kahn's algorithm
                            queue_head <= 4'd0;
                            queue_tail <= 4'd0;
                            nodes_processed <= 4'd0;
                            result_count <= 4'd0;
                            
                            // Find initial nodes with in-degree 0
                            node_idx <= 4'd0;
                        end else begin
                            cycle_count <= cycle_count + 4'd1;
                        end
                    end
                end
                
                SORT: begin
                    // Kahn's algorithm implementation
                    if (nodes_processed < num_nodes) begin
                        // If queue is empty, find nodes with in-degree 0
                        if (queue_head >= queue_tail && node_idx < num_nodes) begin
                            // Check current node
                            if (in_degree[node_idx] == 4'd0) begin
                                // Node has no dependencies, add to queue
                                queue[queue_tail] <= node_idx;
                                queue_tail <= queue_tail + 4'd1;
                                // Mark as processed by setting in-degree to max to avoid re-add
                                in_degree[node_idx] <= 4'd15;
                            end
                            node_idx <= node_idx + 4'd1;
                        end
                        
                        // Process queue
                        if (queue_head < queue_tail) begin
                            // Dequeue
                            temp_node <= queue[queue_head];
                            queue_head <= queue_head + 4'd1;
                            
                            // Add to result
                            result[result_count] <= temp_node;
                            result_count <= result_count + 4'd1;
                            nodes_processed <= nodes_processed + 4'd1;
                            
                            // Update neighbors' in-degrees
                            for (j = 0; j < 10; j = j + 1) begin
                                // Check if edge exists from temp_node to j
                                if (j < num_nodes && temp_node < 10) begin
                                    if (adj[temp_node][j]) begin
                                        in_degree[j] <= (in_degree[j] > 4'd0) ? (in_degree[j] - 4'd1) : 4'd0;
                                    end
                                end
                            end
                        end
                    end else begin
                        // Done processing
                        if (result_count < num_nodes) begin
                            // Cycle detected
                            cycle_detected <= 1'b1;
                        end
                        state <= OUTPUT;
                        output_count <= 4'd0;
                    end
                    
                    // Timeout protection
                    cycle_count <= cycle_count + 4'd1;
                    if (cycle_count >= 4'd15) begin
                        state <= OUTPUT;
                        output_count <= 4'd0;
                        if (result_count < num_nodes) begin
                            cycle_detected <= 1'b1;
                        end
                    end
                end
                
                OUTPUT: begin
                    // Output results sequentially
                    if (output_count < result_count && result_count > 0) begin
                        result_idx <= result[output_count];
                        result_valid <= 1'b1;
                        output_count <= output_count + 4'd1;
                    end else begin
                        result_valid <= 1'b0;
                        if (result_count == 0 || result_count < num_nodes) begin
                            result_empty <= 1'b1;
                        end
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
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