module BadgePathCounter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] s_room,
    input wire [3:0] d_room,
    input wire [4:0] lock_count,
    input wire lock_config_valid,
    input wire [3:0] lock_from,
    input wire [3:0] lock_to,
    input wire [15:0] lock_min,
    input wire [15:0] lock_max,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CONFIG   = 3'd1;
    localparam [2:0] PROC_BUS = 3'd2; // BFS Setup
    localparam [2:0] PROC_RUN = 3'd3; // BFS Execution
    localparam [2:0] PROC_ACC = 3'd4; // Accumulate Result
    localparam [2:0] FINISH   = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Lock Storage (Max 32 locks)
    reg [3:0] lock_from_mem [0:31];
    reg [3:0] lock_to_mem   [0:31];
    reg [15:0] lock_min_mem [0:31];
    reg [15:0] lock_max_mem [0:31];

    // Counters
    reg [4:0] config_idx; // 0 to 31
    reg [4:0] active_lock_cnt; // Actual number of locks configured
    reg [15:0] badge_id; // 0 to 65535
    reg [3:0] bfs_queue [0:15]; // Simple queue
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [15:0] path_count;

    // BFS Visited Array (16 nodes)
    reg [0:15] visited; // Packed for easy reset

    // Internal logic signals
    reg [3:0] current_node;
    reg [3:0] neighbor_node;
    reg [4:0] lock_idx;
    reg path_found;
    reg valid_edge;
    reg visited_check;
    reg queue_empty;

    // Loop indices for for-loops
    integer i;

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start && ready) ? CONFIG : IDLE;
            CONFIG: begin
                if (config_idx >= active_lock_cnt && !lock_config_valid) 
                    next_state = PROC_BUS;
                else 
                    next_state = CONFIG;
            end
            PROC_BUS: next_state = PROC_RUN;
            PROC_RUN: begin
                if (queue_empty) 
                    next_state = PROC_ACC;
                else 
                    next_state = PROC_RUN;
            end
            PROC_ACC: next_state = (badge_id == 16'hFFFF) ? FINISH : PROC_BUS;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State Register and Reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            config_idx <= 5'd0;
            active_lock_cnt <= 5'd0;
            badge_id <= 16'd0;
            path_count <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            visited <= 16'h0000;
            lock_idx <= 5'd0;
            // Initialize memory (optional but good practice)
            for (i = 0; i < 32; i = i + 1) begin
                lock_from_mem[i] <= 4'd0;
                lock_to_mem[i] <= 4'd0;
                lock_min_mem[i] <= 16'd0;
                lock_max_mem[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    if (start && ready) begin
                        active_lock_cnt <= lock_count;
                    end
                end

                CONFIG: begin
                    ready <= 1'b0; // Busy configuring
                    if (lock_config_valid && config_idx < 32) begin
                        lock_from_mem[config_idx] <= lock_from;
                        lock_to_mem[config_idx] <= lock_to;
                        lock_min_mem[config_idx] <= lock_min;
                        lock_max_mem[config_idx] <= lock_max;
                        config_idx <= config_idx + 5'd1;
                    end
                end

                PROC_BUS: begin
                    // Setup BFS for current badge_id
                    visited <= 16'h0000;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    path_found <= 1'b0;
                    
                    // Initialize visited for start node (convert 1-16 to 0-15)
                    // Check bounds: s_room is 1-16. Subtract 1.
                    if (s_room >= 1 && s_room <= 16) begin
                        visited[s_room - 1] <= 1'b1;
                        // Enqueue start
                        bfs_queue[0] <= s_room - 1;
                        queue_tail <= 4'd1;
                    end
                end

                PROC_RUN: begin
                    // Dequeue
                    if (queue_head < queue_tail) begin
                        current_node <= bfs_queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                    end
                end

                PROC_ACC: begin
                    if (path_found) begin
                        path_count <= path_count + 16'd1;
                    end
                    // Increment badge ID
                    badge_id <= badge_id + 16'd1;
                end

                FINISH: begin
                    result <= path_count;
                    done <= 1'b1;
                    ready <= 1'b1;
                    // Reset counters for next run
                    config_idx <= 5'd0;
                    badge_id <= 16'd0;
                    path_count <= 16'd0;
                end
            endcase
        end
    end

    // BFS Logic (Combinational)
    // Runs during PROC_RUN state
    always @(*) begin
        // Default outputs
        queue_empty = (queue_head >= queue_tail);
        visited_check = 1'b0;
        valid_edge = 1'b0;
        
        if (state == PROC_RUN && !queue_empty) begin
            // Check if destination reached
            if (current_node == (d_room - 1)) begin
                path_found = 1'b1;
                // Force queue empty to transition to PROC_ACC
                // We manipulate the tail pointer virtually or check state logic
                // Since this is combinational, we rely on the state machine transition condition
                // However, we need to signal to empty the queue immediately
                // In this FPGA flow, we can just set a flag and the state machine will move on.
            end
            
            // Iterate through all locks to find neighbors from current_node
            // Note: Since we are in combinational block, we can't loop until done easily without FSM states.
            // Instead, we will iterate one lock per cycle or check all in parallel.
            // With 32 locks, checking all in parallel is fine logic-wise but takes routing.
            // Let's check all locks in parallel for the current node.
            
            // We need to know if we found a valid neighbor to enqueue.
            // Since we can only enqueue one node per cycle in hardware without complex logic,
            // we will prioritize the first valid lock found.
            // However, BFS typically processes all neighbors.
            // To keep it simple and bounded:
            // We scan all locks. If a valid lock exists to an unvisited node, we enqueue it.
            // To enqueue multiple, we might need multiple cycles or a wider queue.
            // Given constraints, we will process ONE neighbor per clock cycle.
            // This extends the cycle count but keeps logic small.
            
            // Note: The problem states up to 65k cycles. With 16 nodes and 32 edges, 
            // even if we take 32 cycles per BFS node, it's acceptable.
            // But let's try to do it efficiently.
            // We will look for ANY valid edge in the combinational block and set a `found_neighbor` flag.
        end else begin
            path_found = 1'b0;
        end
    end

    // Sequential Neighbor Processing for BFS
    // We need to handle the neighbor search and enqueueing.
    // Since we are limited by the architecture, let's use the `lock_idx` counter
    // to scan locks one by one during PROC_RUN.
    
    // Modified Control Logic for BFS
    // We need to change PROC_RUN to handle the lock iteration.
    // Let's create a dedicated logic block for the BFS neighbor search.
    
    reg [3:0] neighbor_to_enqueue;
    reg found_neighbor;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lock_idx <= 5'd0;
            found_neighbor <= 1'b0;
        end else if (state == PROC_BUS) begin
            lock_idx <= 5'd0;
            found_neighbor <= 1'b0;
        end else if (state == PROC_RUN && !queue_empty) begin
            if (lock_idx < active_lock_cnt) begin
                // Check current lock
                // lock_from is 1-16, current_node is 0-15
                if ((lock_from_mem[lock_idx] - 1 == current_node) && 
                    !found_neighbor) begin
                    // Check range
                    if (badge_id >= lock_min_mem[lock_idx] && badge_id <= lock_max_mem[lock_idx]) begin
                        // Check if destination is visited
                        if (!visited[lock_to_mem[lock_idx] - 1]) begin
                            found_neighbor <= 1'b1;
                            neighbor_to_enqueue <= lock_to_mem[lock_idx] - 1;
                            // Mark visited immediately to avoid duplicates in same cycle
                            visited[lock_to_mem[lock_idx] - 1] <= 1'b1;
                        end
                    end
                end
                lock_idx <= lock_idx + 5'd1;
            end else begin
                // End of lock scan for this node
                lock_idx <= 5'd0;
                found_neighbor <= 1'b0;
            end
            
            // Enqueue logic (happens if found and we have space)
            if (found_neighbor) begin
                if (queue_tail < 16) begin // Queue size 16 is safe for 16 nodes
                    bfs_queue[queue_tail] <= neighbor_to_enqueue;
                    queue_tail <= queue_tail + 4'd1;
                end
            end
        end
    end
    
    // Override queue_empty logic based on actual processing
    // If we are still scanning locks for the current node, the queue is "effectively" empty 
    // regarding moving to the next state, but we are busy processing the current node.
    // We need to distinguish between "Waiting for next node" and "Processing current node".
    // We add a flag `processing_node` to state logic.
    
    reg processing_node;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing_node <= 1'b0;
        end else begin
            if (state == PROC_RUN) begin
                if (!processing_node && !queue_empty) begin
                    processing_node <= 1'b1; // Start processing a node
                end else if (processing_node && (lock_idx >= active_lock_cnt)) begin
                    processing_node <= 1'b0; // Done processing this node
                end
            end else if (state != PROC_RUN) begin
                processing_node <= 1'b0;
            end
        end
    end

endmodule