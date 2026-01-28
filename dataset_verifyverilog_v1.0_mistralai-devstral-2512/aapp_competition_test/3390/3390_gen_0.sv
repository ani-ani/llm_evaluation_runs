module GraphMaxPath(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [5:0] m,
    input [3:0] edge_a,
    input [3:0] edge_b,
    output reg [7:0] result,
    output reg done,
    output reg valid
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Graph storage
    reg [3:0] edges [0:31]; // edge_a
    reg [3:0] edges_to [0:31]; // edge_b
    reg [7:0] dist [0:15]; // dist[node]
    reg [7:0] max_dist;
    
    // BFS queue
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] current_node;
    
    // Edge loading
    reg [5:0] edge_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            edge_idx <= 6'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                dist[i] <= 8'd0;
                queue[i] <= 4'd0;
            end
            for (i = 0; i < 32; i = i + 1) begin
                edges[i] <= 4'd0;
                edges_to[i] <= 4'd0;
            end
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            current_node <= 4'd0;
            max_dist <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                        edge_idx <= 6'd0;
                    end
                end
                
                LOAD: begin
                    if (edge_idx < m) begin
                        edges[edge_idx] <= edge_a;
                        edges_to[edge_idx] <= edge_b;
                        edge_idx <= edge_idx + 6'd1;
                    end else begin
                        state <= COMPUTE;
                        // Initialize distances
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            dist[i] <= 8'd0;
                        end
                        // Initialize queue with all nodes
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        for (i = 0; i < n; i = i + 1) begin
                            queue[queue_tail] <= i;
                            queue_tail <= queue_tail + 4'd1;
                        end
                        current_node <= 4'd0;
                        max_dist <= 8'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current node
                    if (queue_head < queue_tail) begin
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        
                        // Update neighbors
                        integer i;
                        for (i = 0; i < m; i = i + 1) begin
                            if (edges[i] == current_node) begin
                                reg [3:0] neighbor = edges_to[i];
                                if (dist[neighbor] < dist[current_node] + 8'd1) begin
                                    dist[neighbor] <= dist[current_node] + 8'd1;
                                    // Add to queue if not already there
                                    // (simple approach: always add, may have duplicates)
                                    queue[queue_tail] <= neighbor;
                                    queue_tail <= queue_tail + 4'd1;
                                end
                            end
                        end
                        
                        // Track max distance
                        if (dist[current_node] > max_dist) begin
                            max_dist <= dist[current_node];
                        end
                    end
                    
                    // Check completion
                    if (queue_head >= queue_tail || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    result <= max_dist + 8'd1; // +1 for path length
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule