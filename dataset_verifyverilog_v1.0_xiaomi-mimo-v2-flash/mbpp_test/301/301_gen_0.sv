module tree_max_depth (
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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    localparam [2:0] ERROR_STATE = 3'd4;

    // Adjacency matrix: adj[parent][child] = 1
    reg [15:0] adj [15:0];
    
    // Depth array: depth[node] = depth (1-indexed)
    reg [7:0] depth [15:0];
    
    // Queue for BFS (16 entries, 4 bits each)
    reg [3:0] queue [15:0];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] queue_count;
    
    // FSM
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Temporary registers
    reg [3:0] current_node;
    reg [3:0] child_node;
    reg [3:0] node_idx;
    reg [3:0] child_idx;
    reg [7:0] max_depth;
    reg [7:0] cycle_count;
    reg [3:0] load_idx;
    reg [3:0] i;
    reg [3:0] j;
    reg tree_loaded_reg;
    reg start_reg;
    reg [3:0] parent_check;
    
    // Edge case tracking
    reg invalid_tree;
    reg [3:0] root_children_count;
    
    // Queue operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_count <= 4'd0;
        end else begin
            if (state == IDLE && next_state == COMPUTE) begin
                queue_head <= 4'd0;
                queue_tail <= 4'd1;
                queue_count <= 4'd1;
                queue[0] <= 4'd0; // Root node 0
            end else if (state == COMPUTE) begin
                if (queue_count > 4'd0) begin
                    queue_head <= queue_head + 4'd1;
                    queue_count <= queue_count - 4'd1;
                end
                // Add children to tail
                if (current_node != 4'd15 && child_idx != 4'd15) begin
                    // This is handled in the main FSM logic
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
            invalid_tree <= 1'b0;
            tree_loaded_reg <= 1'b0;
            start_reg <= 1'b0;
            // Initialize depth array
            for (i = 4'd0; i < 4'd16; i = i + 4'd1) begin
                depth[i] <= 8'd0;
            end
            // Initialize adjacency matrix
            for (i = 4'd0; i < 4'd16; i = i + 4'd1) begin
                adj[i] <= 16'h0000;
            end
        end else begin
            tree_loaded_reg <= tree_loaded;
            start_reg <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    invalid_tree <= 1'b0;
                    
                    // Clear depth array
                    for (i = 4'd0; i < 4'd16; i = i + 4'd1) begin
                        depth[i] <= 8'd0;
                    end
                    
                    // Check if ready to compute
                    if (start && tree_loaded_reg) begin
                        state <= COMPUTE;
                        // Initialize for compute
                        max_depth <= 8'd1;
                        depth[4'd0] <= 8'd1; // Root at depth 1
                        current_node <= 4'd0;
                        child_idx <= 4'd0;
                        node_idx <= 4'd0;
                        root_children_count <= 4'd0;
                        // Initialize queue
                        queue_head <= 4'd0;
                        queue_tail <= 4'd1;
                        queue_count <= 4'd1;
                        queue[0] <= 4'd0;
                    end else if (start && !tree_loaded_reg) begin
                        error <= 1'b1;
                        state <= ERROR_STATE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // If invalid tree detected earlier
                    if (invalid_tree) begin
                        error <= 1'b1;
                        state <= ERROR_STATE;
                    end else if (queue_count > 4'd0) begin
                        // Process current node
                        current_node <= queue[queue_head];
                        
                        // Find children
                        if (child_idx < 4'd16) begin
                            if (adj[current_node][child_idx]) begin
                                // Found a child
                                if (depth[child_idx] == 8'd0) begin
                                    // First time visiting this child
                                    depth[child_idx] <= depth[current_node] + 8'd1;
                                    if (depth[current_node] + 8'd1 > max_depth) begin
                                        max_depth <= depth[current_node] + 8'd1;
                                    end
                                    
                                    // Check if queue is full
                                    if (queue_count < 4'd16) begin
                                        queue[queue_tail] <= child_idx;
                                        queue_tail <= queue_tail + 4'd1;
                                        queue_count <= queue_count + 4'd1;
                                        
                                        // Check for cycles: if child is already in queue
                                        for (j = 4'd0; j < 4'd16; j = j + 4'd1) begin
                                            if (j < queue_count && queue[j] == child_idx) begin
                                                invalid_tree <= 1'b1;
                                            end
                                        end
                                    end else begin
                                        // Queue full, invalid tree or need to handle
                                        invalid_tree <= 1'b1;
                                    end
                                end else begin
                                    // Already visited, check for cycle (parent->child where child depth < parent depth)
                                    if (depth[child_idx] <= depth[current_node]) begin
                                        invalid_tree <= 1'b1;
                                    end
                                end
                                child_idx <= child_idx + 4'd1;
                            end else begin
                                child_idx <= child_idx + 4'd1;
                            end
                        end else begin
                            // Done processing this node, move to next in queue
                            child_idx <= 4'd0;
                            
                            // Check if queue becomes empty
                            if (queue_count == 4'd0 || (queue_count == 4'd1 && queue_head == queue_tail)) begin
                                state <= DONE_STATE;
                            end
                        end
                    end else begin
                        // No more nodes in queue
                        state <= DONE_STATE;
                    end
                    
                    // Safety timeout
                    if (cycle_count > 8'd200) begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= max_depth;
                    state <= IDLE;
                end
                
                ERROR_STATE: begin
                    error <= 1'b1;
                    result <= 8'd0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Load phase logic (combinational)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main FSM
        end else begin
            if (load_valid && load_addr < 4'd16) begin
                if (load_child < 4'd16) begin
                    adj[load_parent][load_child] <= 1'b1;
                end
            end
        end
    end

endmodule