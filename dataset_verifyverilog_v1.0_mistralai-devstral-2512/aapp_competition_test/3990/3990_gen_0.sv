module TrainBusSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] m_in,
    input wire [3:0] edge_u,
    input wire [3:0] edge_v,
    input wire edge_valid,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] BFS_INIT   = 3'd2;
    localparam [2:0] BFS_RUN    = 3'd3;
    localparam [2:0] OUTPUT     = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Edge loading counters
    reg [3:0] edge_count;
    reg [3:0] edge_index;
    
    // Railway matrix (16x16)
    reg [15:0] rail_mat [0:15];
    integer i, j;
    
    // BFS variables
    reg [3:0] current_node;
    reg [3:0] neighbor_idx;
    reg [7:0] dist [0:15];
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg queue_empty, queue_full;
    
    // Graph selection
    reg use_road_graph;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            edge_count <= 4'd0;
            edge_index <= 4'd0;
            
            // Initialize rail_mat to all zeros
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    rail_mat[i][j] <= 1'b0;
                end
            end
            
            // Initialize BFS variables
            current_node <= 4'd0;
            neighbor_idx <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                dist[i] <= 8'd255;
            end
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_empty <= 1'b1;
            queue_full <= 1'b0;
            use_road_graph <= 1'b0;
            cycle_count <= 8'd0;
            
            // Outputs
            result <= 8'd255;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end
    
    // Edge loading FSM
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state <= LOAD_EDGES;
                    edge_count <= 4'd0;
                    edge_index <= 4'd0;
                end else begin
                    next_state <= IDLE;
                end
            end
            
            LOAD_EDGES: begin
                if (edge_valid && edge_count < m_in) begin
                    // Store edge in rail_mat (both directions)
                    rail_mat[edge_u][edge_v] <= 1'b1;
                    rail_mat[edge_v][edge_u] <= 1'b1;
                    edge_count <= edge_count + 4'd1;
                end
                
                if (edge_count >= m_in) begin
                    // Determine which graph to use
                    use_road_graph <= rail_mat[0][n_in - 1];
                    next_state <= BFS_INIT;
                end else begin
                    next_state <= LOAD_EDGES;
                end
            end
            
            BFS_INIT: begin
                // Initialize BFS
                dist[0] <= 8'd0;
                queue[0] <= 4'd0;
                queue_head <= 4'd0;
                queue_tail <= 4'd1;
                queue_empty <= 1'b0;
                queue_full <= 1'b0;
                neighbor_idx <= 4'd0;
                cycle_count <= 8'd0;
                next_state <= BFS_RUN;
            end
            
            BFS_RUN: begin
                cycle_count <= cycle_count + 8'd1;
                
                if (!queue_empty && cycle_count < MAX_CYCLES) begin
                    // Process current node
                    current_node <= queue[queue_head];
                    
                    // Check if we reached destination
                    if (current_node == n_in - 1) begin
                        next_state <= OUTPUT;
                    end else begin
                        // Explore neighbors
                        if (neighbor_idx < n_in) begin
                            if (neighbor_idx != current_node) begin
                                reg connect;
                                if (use_road_graph) begin
                                    connect = ~rail_mat[current_node][neighbor_idx];
                                end else begin
                                    connect = rail_mat[current_node][neighbor_idx];
                                end
                                
                                if (connect && dist[neighbor_idx] == 8'd255) begin
                                    dist[neighbor_idx] <= dist[current_node] + 8'd1;
                                    
                                    // Push to queue
                                    if (!queue_full) begin
                                        queue[queue_tail] <= neighbor_idx;
                                        queue_tail <= queue_tail + 4'd1;
                                        if (queue_tail == 16) begin
                                            queue_tail <= 4'd0;
                                        end
                                        queue_full <= (queue_tail == queue_head);
                                    end
                                end
                            end
                            neighbor_idx <= neighbor_idx + 4'd1;
                        end else begin
                            // Move to next node in queue
                            queue_head <= queue_head + 4'd1;
                            if (queue_head == 16) begin
                                queue_head <= 4'd0;
                            end
                            queue_empty <= (queue_head == queue_tail);
                            neighbor_idx <= 4'd0;
                        end
                    end
                end else begin
                    next_state <= OUTPUT;
                end
            end
            
            OUTPUT: begin
                result <= dist[n_in - 1];
                done <= 1'b1;
                next_state <= IDLE;
            end
            
            default: next_state <= IDLE;
        endcase
    end
    
    // Queue status logic
    always @(*) begin
        queue_empty = (queue_head == queue_tail);
        queue_full = ((queue_tail + 4'd1) % 16) == queue_head;
    end

endmodule