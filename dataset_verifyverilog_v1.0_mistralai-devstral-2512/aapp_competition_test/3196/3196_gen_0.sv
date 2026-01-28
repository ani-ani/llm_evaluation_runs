module RouteCounter(
    input clk,
    input rst_n,
    input start,
    input edges_valid,
    input [3:0] src_node,
    input [3:0] dst_node,
    input [4:0] edge_count,
    output reg [31:0] result,
    output reg inf_flag,
    output reg done,
    output reg error
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_EDGES = 4'd1;
    localparam [3:0] DETECT_CYCLES = 4'd2;
    localparam [3:0] COUNT_PATHS = 4'd3;
    localparam [3:0] DONE_STATE = 4'd4;
    
    reg [3:0] state, next_state;
    
    // Edge storage (max 32 edges)
    reg [3:0] edge_src [0:31];
    reg [3:0] edge_dst [0:31];
    reg [4:0] edge_idx;
    reg [4:0] loaded_edges;
    
    // Graph representation
    reg [3:0] adj_list [0:15];
    reg [4:0] adj_count [0:15];
    
    // Cycle detection
    reg [1:0] visit_state [0:15];
    reg [3:0] current_node;
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg cycle_detected;
    
    // Path counting
    reg [31:0] dp [0:15];
    reg [3:0] dp_idx;
    reg [3:0] neighbor_idx;
    
    // Control
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    // Constants
    localparam [31:0] MODULUS = 32'd1000000000;
    localparam [3:0] SOURCE = 4'd0;
    localparam [3:0] DEST = 4'd1;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Clear edge storage
            edge_idx <= 5'd0;
            loaded_edges <= 5'd0;
            
            // Clear graph
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                adj_count[i] <= 5'd0;
                visit_state[i] <= 2'd0;
                dp[i] <= 32'd0;
            end
            
            // Clear stack
            stack_ptr <= 4'd0;
            current_node <= 4'd0;
            cycle_detected <= 1'b0;
            
            // Clear outputs
            result <= 32'd0;
            inf_flag <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            
            cycle_counter <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_EDGES;
                    loaded_edges = 5'd0;
                    edge_idx = 5'd0;
                end
            end
            
            LOAD_EDGES: begin
                if (edges_valid && edge_idx < edge_count) begin
                    // Store edge
                    edge_src[edge_idx] = src_node;
                    edge_dst[edge_idx] = dst_node;
                    next_state = LOAD_EDGES;
                end else if (edge_idx >= edge_count) begin
                    // Build adjacency list
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        adj_count[i] = 5'd0;
                    end
                    
                    for (i = 0; i < edge_count; i = i + 1) begin
                        reg [3:0] s = edge_src[i];
                        reg [3:0] d = edge_dst[i];
                        if (adj_count[s] < 5'd32) begin
                            adj_list[{s, adj_count[s]}] = d;
                            adj_count[s] = adj_count[s] + 5'd1;
                        end
                    end
                    
                    next_state = DETECT_CYCLES;
                    stack_ptr = 4'd0;
                    current_node = SOURCE;
                    cycle_detected = 1'b0;
                    
                    // Initialize visit states
                    for (i = 0; i < 16; i = i + 1) begin
                        visit_state[i] = 2'd0;
                    end
                end
            end
            
            DETECT_CYCLES: begin
                if (cycle_counter >= MAX_CYCLES) begin
                    next_state = COUNT_PATHS;
                end else if (current_node == DEST) begin
                    next_state = COUNT_PATHS;
                end else begin
                    reg [1:0] current_visit = visit_state[current_node];
                    
                    if (current_visit == 2'd0) begin
                        // Unvisited - mark as visiting
                        visit_state[current_node] = 2'd1;
                        stack[stack_ptr] = current_node;
                        stack_ptr = stack_ptr + 4'd1;
                        
                        // Move to first neighbor
                        if (adj_count[current_node] > 5'd0) begin
                            current_node = adj_list[{current_node, 5'd0}];
                        end else begin
                            // No neighbors - backtrack
                            if (stack_ptr > 4'd0) begin
                                stack_ptr = stack_ptr - 4'd1;
                                current_node = stack[stack_ptr];
                                visit_state[current_node] = 2'd2;
                            end else begin
                                next_state = COUNT_PATHS;
                            end
                        end
                    end else if (current_visit == 2'd1) begin
                        // Cycle detected
                        cycle_detected = 1'b1;
                        next_state = COUNT_PATHS;
                    end else begin
                        // Already visited - backtrack
                        if (stack_ptr > 4'd0) begin
                            stack_ptr = stack_ptr - 4'd1;
                            current_node = stack[stack_ptr];
                            visit_state[current_node] = 2'd2;
                        end else begin
                            next_state = COUNT_PATHS;
                        end
                    end
                    
                    cycle_counter = cycle_counter + 8'd1;
                end
            end
            
            COUNT_PATHS: begin
                if (cycle_detected) begin
                    inf_flag = 1'b1;
                    next_state = DONE_STATE;
                end else if (dp_idx == 4'd0) begin
                    // Initialize DP
                    dp[SOURCE] = 32'd1;
                    dp_idx = 4'd1;
                end else if (dp_idx < 4'd16) begin
                    reg [3:0] node = dp_idx;
                    reg [31:0] count = 32'd0;
                    
                    // Sum counts from all predecessors
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        reg [4:0] cnt = adj_count[i];
                        integer j;
                        for (j = 0; j < cnt; j = j + 1) begin
                            if (adj_list[{i, j}] == node) begin
                                count = (count + dp[i]) % MODULUS;
                            end
                        end
                    end
                    
                    dp[node] = count;
                    dp_idx = dp_idx + 4'd1;
                end else begin
                    // Done with DP
                    result = dp[DEST];
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Edge loading counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_idx <= 5'd0;
        end else if (state == LOAD_EDGES && edges_valid) begin
            edge_idx <= edge_idx + 5'd1;
        end
    end
    
    // Cycle counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 8'd0;
        end else if (state == DETECT_CYCLES) begin
            cycle_counter <= cycle_counter + 8'd1;
        end
    end
    
    // Error detection (invalid edge count)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error <= 1'b0;
        end else if (state == IDLE && start && edge_count > 5'd32) begin
            error <= 1'b1;
        end else if (state != IDLE) begin
            error <= 1'b0;
        end
    end
    
    // Done signal (pulse)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule