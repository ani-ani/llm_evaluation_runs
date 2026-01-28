module TravelSalesmanAirport(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] m,
    input [3:0] edge_a,
    input [3:0] edge_b,
    input edge_valid,
    input edge_done,
    output reg [4:0] min_flights,
    output reg [4:0] airport_count,
    output reg [15:0] airport_list,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] STORE_EDGES      = 4'd1;
    localparam [3:0] CHECK_ISOLATED   = 4'd2;
    localparam [3:0] INIT_BFS         = 4'd3;
    localparam [3:0] FIND_SOURCES     = 4'd4;
    localparam [3:0] BFS_LOOP         = 4'd5;
    localparam [3:0] COMPONENT_COUNT  = 4'd6;
    localparam [3:0] CALC_AIRPORTS    = 4'd7;
    localparam [3:0] FINISH           = 4'd8;

    // Registers for state machine
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Cycle counter for timeout protection
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Graph storage: Adjacency matrix 16x16 bits
    // row i has bit j set if edge i->j exists
    reg [15:0] adj_matrix [0:15];
    
    // Degree arrays
    reg [3:0] indegree [0:15];
    reg [3:0] outdegree [0:15];
    
    // BFS visited array
    reg [15:0] visited;
    
    // Working registers
    reg [3:0] current_node;
    reg [3:0] neighbor_node;
    reg [3:0] node_idx;
    reg [3:0] component_count;
    reg [15:0] temp_airport_list;
    reg [3:0] temp_airport_count;
    
    // Edge storage buffer
    reg [3:0] edge_buffer_a [0:31];
    reg [3:0] edge_buffer_b [0:31];
    reg [4:0] edge_index;
    reg [4:0] edges_stored;
    
    // Queue for BFS (simple FIFO using registers)
    reg [3:0] queue [0:15];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] queue_count;

    // Helper function to check if node exists (<= n)
    function automatic node_valid;
        input [3:0] node;
        begin
            node_valid = (node < n) && (n != 0);
        end
    endfunction

    // Reset initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_flights <= 5'd0;
            airport_count <= 5'd0;
            airport_list <= 16'd0;
            cycle_counter <= 8'd0;
            edge_index <= 5'd0;
            edges_stored <= 5'd0;
            
            // Initialize arrays
            for (node_idx = 4'd0; node_idx < 4'd16; node_idx = node_idx + 4'd1) begin
                adj_matrix[node_idx] <= 16'd0;
                indegree[node_idx] <= 4'd0;
                outdegree[node_idx] <= 4'd0;
            end
        end else begin
            // State transition
            state <= next_state;
            
            // Clear done flag unless in finish state
            if (state != FINISH) begin
                done <= 1'b0;
            end
            
            // Increment cycle counter (unless idle)
            if (state != IDLE && state != FINISH) begin
                if (cycle_counter < MAX_CYCLES) begin
                    cycle_counter <= cycle_counter + 8'd1;
                end
            end
            
            // State-specific operations
            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    edge_index <= 5'd0;
                    edges_stored <= 5'd0;
                    component_count <= 4'd0;
                    visited <= 16'd0;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    queue_count <= 4'd0;
                    // Clear arrays
                    for (node_idx = 4'd0; node_idx < 4'd16; node_idx = node_idx + 4'd1) begin
                        adj_matrix[node_idx] <= 16'd0;
                        indegree[node_idx] <= 4'd0;
                        outdegree[node_idx] <= 4'd0;
                    end
                end
                
                STORE_EDGES: begin
                    if (edge_valid && edge_index < 5'd32) begin
                        if (node_valid(edge_a) && node_valid(edge_b)) begin
                            edge_buffer_a[edge_index] <= edge_a;
                            edge_buffer_b[edge_index] <= edge_b;
                            edge_index <= edge_index + 5'd1;
                        end
                    end
                    if (edge_done) begin
                        edges_stored <= edge_index;
                    end
                end
                
                CHECK_ISOLATED: begin
                    // Build adjacency matrix and degree arrays from buffer
                    for (node_idx = 4'd0; node_idx < 4'd16; node_idx = node_idx + 4'd1) begin
                        adj_matrix[node_idx] <= 16'd0;
                        indegree[node_idx] <= 4'd0;
                        outdegree[node_idx] <= 4'd0;
                    end
                end
                
                INIT_BFS: begin
                    // Start BFS from first node that exists
                    visited <= 16'd0;
                    component_count <= 4'd0;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    queue_count <= 4'd0;
                end
                
                FIND_SOURCES: begin
                    // Find a node that hasn't been visited yet
                    if (current_node < n) begin
                        if (!visited[current_node]) begin
                            // Found unvisited node, start new component
                            visited[current_node] <= 1'b1;
                            queue[queue_tail] <= current_node;
                            queue_tail <= queue_tail + 4'd1;
                            queue_count <= queue_count + 4'd1;
                            component_count <= component_count + 4'd1;
                            current_node <= 4'd0; // Reset for BFS traversal
                        end else begin
                            current_node <= current_node + 4'd1;
                        end
                    end
                end
                
                BFS_LOOP: begin
                    if (queue_count > 4'd0) begin
                        // Dequeue
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        queue_count <= queue_count - 4'd1;
                        neighbor_node <= 4'd0;
                    end else if (current_node < n) begin
                        // Continue looking for unvisited nodes
                        if (!visited[current_node]) begin
                            visited[current_node] <= 1'b1;
                            queue[queue_tail] <= current_node;
                            queue_tail <= queue_tail + 4'd1;
                            queue_count <= queue_count + 4'd1;
                            component_count <= component_count + 4'd1;
                            current_node <= 4'd0;
                        end else begin
                            current_node <= current_node + 4'd1;
                        end
                    end
                end
                
                COMPONENT_COUNT: begin
                    // Process neighbors of current_node
                    if (neighbor_node < n) begin
                        if (adj_matrix[current_node][neighbor_node]) begin
                            if (!visited[neighbor_node]) begin
                                visited[neighbor_node] <= 1'b1;
                                queue[queue_tail] <= neighbor_node;
                                queue_tail <= queue_tail + 4'd1;
                                queue_count <= queue_count + 4'd1;
                            end
                        end
                        neighbor_node <= neighbor_node + 4'd1;
                    end else begin
                        // Done with this node, go back to BFS_LOOP
                        neighbor_node <= 4'd0;
                    end
                end
                
                CALC_AIRPORTS: begin
                    // Calculate min_flights = components - 1 (if > 0)
                    if (component_count > 4'd0) begin
                        min_flights <= {1'b0, component_count} - 5'd1;
                    end else begin
                        min_flights <= 5'd0;
                    end
                    
                    // Build airport list
                    temp_airport_list <= 16'd0;
                    temp_airport_count <= 4'd0;
                    node_idx <= 4'd0;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    airport_list <= temp_airport_list;
                    airport_count <= {1'b0, temp_airport_count};
                end
            endcase
        end
    end

    // Combinational logic for state transitions
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = STORE_EDGES;
                end
            end
            
            STORE_EDGES: begin
                if (edge_done && !edge_valid) begin
                    next_state = CHECK_ISOLATED;
                end
            end
            
            CHECK_ISOLATED: begin
                // Build matrices from stored edges
                next_state = INIT_BFS;
            end
            
            INIT_BFS: begin
                current_node = 4'd0;
                next_state = FIND_SOURCES;
            end
            
            FIND_SOURCES: begin
                if (current_node >= n) begin
                    // All nodes processed for this component
                    if (queue_count == 4'd0) begin
                        // No more components
                        next_state = CALC_AIRPORTS;
                    end else begin
                        // Continue BFS
                        current_node = 4'd0;
                        next_state = BFS_LOOP;
                    end
                end else begin
                    // Check if this node was visited
                    if (visited[current_node]) begin
                        current_node = current_node + 4'd1;
                        next_state = FIND_SOURCES;
                    end else begin
                        // Found new source for component
                        next_state = BFS_LOOP;
                    end
                end
            end
            
            BFS_LOOP: begin
                if (queue_count > 4'd0) begin
                    // Processing node from queue
                    next_state = COMPONENT_COUNT;
                end else if (current_node < n) begin
                    // Check for more unvisited nodes
                    if (!visited[current_node]) begin
                        // Found new node to start component
                        next_state = FIND_SOURCES;
                    end else begin
                        current_node = current_node + 4'd1;
                        next_state = BFS_LOOP;
                    end
                end else begin
                    // Check if more nodes to process
                    next_state = FIND_SOURCES;
                end
            end
            
            COMPONENT_COUNT: begin
                if (neighbor_node >= n) begin
                    next_state = BFS_LOOP;
                end else begin
                    next_state = COMPONENT_COUNT;
                end
            end
            
            CALC_AIRPORTS: begin
                if (node_idx < n) begin
                    // If min_flights > 0, include nodes with degree > 0
                    // If min_flights == 0, include all nodes
                    if (min_flights > 5'd0) begin
                        if ((indegree[node_idx] + outdegree[node_idx]) > 4'd0) begin
                            temp_airport_list[node_idx] = 1'b1;
                            temp_airport_count = temp_airport_count + 4'd1;
                        end
                    end else begin
                        // min_flights == 0, include all nodes
                        temp_airport_list[node_idx] = 1'b1;
                        temp_airport_count = temp_airport_count + 4'd1;
                    end
                    node_idx = node_idx + 4'd1;
                    next_state = CALC_AIRPORTS;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                if (start) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Additional combinational logic for building adjacency matrix
    // This needs to happen in CHECK_ISOLATED state
    always @(*) begin
        if (state == CHECK_ISOLATED) begin
            // Rebuild adjacency matrix and degrees from buffer
            for (int i = 0; i < 16; i = i + 1) begin
                adj_matrix[i] = adj_matrix[i]; // Keep existing
            end
        end
    end

    // Actual edge processing (combinational for performance)
    always @(*) begin
        integer j;
        for (j = 0; j < 32; j = j + 1) begin
            if (state == CHECK_ISOLATED && j < edges_stored) begin
                if (node_valid(edge_buffer_a[j]) && node_valid(edge_buffer_b[j])) begin
                    adj_matrix[edge_buffer_a[j]][edge_buffer_b[j]] = 1'b1;
                    outdegree[edge_buffer_a[j]] = outdegree[edge_buffer_a[j]] + 4'd1;
                    indegree[edge_buffer_b[j]] = indegree[edge_buffer_b[j]] + 4'd1;
                end
            end
        end
    end

endmodule