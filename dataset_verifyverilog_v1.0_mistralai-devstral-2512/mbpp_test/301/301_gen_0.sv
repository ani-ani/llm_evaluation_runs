module TreeDepthCalculator(
    input clk,
    input rst_n,
    input start,
    input tree_loaded,
    input [3:0] load_addr,
    input [3:0] load_parent,
    input [3:0] load_child,
    input load_valid,
    output reg [7:0] result,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    localparam [2:0] ERROR   = 3'd4;

    // Adjacency matrix (16x16)
    reg [15:0] adj [0:15];
    
    // Depth storage (16 nodes, 8-bit depth)
    reg [7:0] depth [0:15];
    
    // Queue for BFS (16 entries, 4-bit node ID)
    reg [3:0] queue [0:15];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    
    // Current level tracking
    reg [7:0] current_level;
    reg [7:0] max_depth;
    
    // FSM state
    reg [2:0] state;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Tree validation flags
    reg [15:0] visited;
    reg has_root;
    reg has_cycle;
    reg has_invalid_id;
    
    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
            end
            
            // Initialize depth array
            for (i = 0; i < 16; i = i + 1) begin
                depth[i] <= 8'd0;
            end
            
            // Initialize queue
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                queue[i] <= 4'd0;
            end
            
            current_level <= 8'd0;
            max_depth <= 8'd0;
            visited <= 16'd0;
            has_root <= 1'b0;
            has_cycle <= 1'b0;
            has_invalid_id <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (load_valid) begin
                        state <= LOAD;
                    end else if (start && tree_loaded) begin
                        state <= COMPUTE;
                    end
                end
                
                LOAD: begin
                    // Store parent-child relationship
                    if (load_addr < 16 && load_parent < 16 && load_child < 16) begin
                        adj[load_addr][load_child] <= 1'b1;
                    end
                    
                    if (!load_valid) begin
                        state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count > MAX_CYCLES) begin
                        state <= ERROR;
                        error <= 1'b1;
                    end else begin
                        // Validate tree structure
                        if (!has_root) begin
                            // Check if root (node 0) exists
                            if (adj[0] != 16'd0) begin
                                has_root <= 1'b1;
                                
                                // Initialize BFS
                                depth[0] <= 8'd1;
                                queue[0] <= 4'd0;
                                queue_head <= 4'd0;
                                queue_tail <= 4'd1;
                                current_level <= 8'd1;
                                max_depth <= 8'd1;
                                visited[0] <= 1'b1;
                            end
                        end else begin
                            // Process queue
                            if (queue_head != queue_tail) begin
                                reg [3:0] current_node;
                                current_node <= queue[queue_head];
                                
                                // Process children
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (adj[current_node][i] && !visited[i]) begin
                                        // Check for cycles
                                        if (i == current_node) begin
                                            has_cycle <= 1'b1;
                                        end else begin
                                            depth[i] <= current_level + 8'd1;
                                            if (depth[i] > max_depth) begin
                                                max_depth <= depth[i];
                                            end
                                            
                                            // Add to queue
                                            queue[queue_tail] <= i;
                                            queue_tail <= queue_tail + 4'd1;
                                            visited[i] <= 1'b1;
                                        end
                                    end
                                end
                                
                                queue_head <= queue_head + 4'd1;
                                
                                // Check if queue is empty
                                if (queue_head == queue_tail) begin
                                    state <= DONE;
                                    result <= max_depth;
                                    done <= 1'b1;
                                end
                            end else begin
                                state <= DONE;
                                result <= max_depth;
                                done <= 1'b1;
                            end
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR: begin
                    error <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Validate tree structure during computation
    always @(*) begin
        if (has_cycle || has_invalid_id || !has_root) begin
            error = 1'b1;
        end else begin
            error = 1'b0;
        end
    end

endmodule