module TopologicalSort(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [9:0] edge_valid,
    input [3:0] edge_from,
    input [3:0] edge_to,
    input edge_wr,
    output reg [3:0] result_idx,
    output reg result_valid,
    output reg done,
    output reg cycle_detected,
    output reg result_empty
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD_EDGES = 2'd1;
    localparam [1:0] SORT = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state, next_state;

    // Adjacency matrix (10x10)
    reg [9:0] adj [0:9];
    integer i, j;

    // In-degree counters
    reg [3:0] in_degree [0:9];

    // Queue for nodes with in-degree 0
    reg [3:0] queue [0:9];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] queue_size;

    // Result storage
    reg [3:0] result [0:9];
    reg [3:0] result_ptr;

    // Cycle detection
    reg [3:0] processed_count;

    // Edge loading counter
    reg [3:0] edge_count;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
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
            
            // Initialize in-degree counters
            for (i = 0; i < 10; i = i + 1) begin
                in_degree[i] <= 4'd0;
            end
            
            // Initialize queue
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_size <= 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                queue[i] <= 4'd0;
            end
            
            // Initialize result storage
            result_ptr <= 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                result[i] <= 4'd0;
            end
            
            // Initialize counters
            processed_count <= 4'd0;
            edge_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Edge loading state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized above
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= LOAD_EDGES;
                        edge_count <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_EDGES: begin
                    if (edge_wr && edge_valid[edge_from]) begin
                        // Set adjacency matrix bit
                        adj[edge_from][edge_to] <= 1'b1;
                        // Increment in-degree of destination
                        in_degree[edge_to] <= in_degree[edge_to] + 4'd1;
                        edge_count <= edge_count + 4'd1;
                    end
                    
                    // Check if all edges are loaded (edge_count >= num_nodes-1)
                    if (edge_count >= num_nodes - 4'd1) begin
                        next_state <= SORT;
                    end else begin
                        next_state <= LOAD_EDGES;
                    end
                end

                SORT: begin
                    // Kahn's algorithm implementation
                    if (queue_size == 4'd0) begin
                        // Initialize queue with nodes having in-degree 0
                        for (i = 0; i < num_nodes; i = i + 1) begin
                            if (in_degree[i] == 4'd0) begin
                                queue[queue_tail] <= i;
                                queue_tail <= queue_tail + 4'd1;
                                queue_size <= queue_size + 4'd1;
                            end
                        end
                    end else begin
                        // Process node from queue (smallest index first)
                        reg [3:0] current_node;
                        current_node <= queue[queue_head];
                        
                        // Add to result
                        result[result_ptr] <= current_node;
                        result_ptr <= result_ptr + 4'd1;
                        processed_count <= processed_count + 4'd1;
                        
                        // Remove edges from current node
                        for (j = 0; j < num_nodes; j = j + 1) begin
                            if (adj[current_node][j]) begin
                                in_degree[j] <= in_degree[j] - 4'd1;
                                
                                // If in-degree becomes 0, add to queue
                                if (in_degree[j] == 4'd0) begin
                                    queue[queue_tail] <= j;
                                    queue_tail <= queue_tail + 4'd1;
                                    queue_size <= queue_size + 4'd1;
                                end
                            end
                        end
                        
                        // Remove current node from queue
                        queue_head <= queue_head + 4'd1;
                        queue_size <= queue_size - 4'd1;
                    end
                    
                    // Check if done
                    if (processed_count == num_nodes) begin
                        next_state <= DONE;
                        cycle_detected <= 1'b0;
                    end else if (queue_size == 4'd0 && processed_count < num_nodes) begin
                        next_state <= DONE;
                        cycle_detected <= 1'b1;
                    end else begin
                        next_state <= SORT;
                    end
                end

                DONE: begin
                    if (result_ptr > 4'd0) begin
                        result_ptr <= result_ptr - 4'd1;
                        result_idx <= result[result_ptr];
                        result_valid <= 1'b1;
                    end else begin
                        result_valid <= 1'b0;
                    end
                    
                    if (result_ptr == 4'd0) begin
                        done <= 1'b1;
                        result_empty <= (cycle_detected || (num_nodes == 4'd0));
                    end else begin
                        done <= 1'b0;
                    end
                    
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule