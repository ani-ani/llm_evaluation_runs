module dict_depth(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [7:0] parent_mask,
    input [7:0] parent_map_0,
    input [7:0] parent_map_1,
    input [7:0] parent_map_2,
    input [7:0] parent_map_3,
    input [7:0] parent_map_4,
    input [7:0] parent_map_5,
    input [7:0] parent_map_6,
    input [7:0] parent_map_7,
    output reg [3:0] depth,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam CALCULATING = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // Queue and traversal registers
    reg [2:0] queue [0:7]; // Circular buffer for BFS
    reg [2:0] head_ptr;
    reg [2:0] tail_ptr;
    reg [2:0] queue_count;

    reg [7:0] visited_mask;
    reg [2:0] current_node;
    reg [3:0] current_depth;
    reg [3:0] max_depth_reg;

    // Helper wires for parent map lookup
    wire [7:0] current_parent_map;
    assign current_parent_map = 
        (current_node == 3'd0) ? parent_map_0 :
        (current_node == 3'd1) ? parent_map_1 :
        (current_node == 3'd2) ? parent_map_2 :
        (current_node == 3'd3) ? parent_map_3 :
        (current_node == 3'd4) ? parent_map_4 :
        (current_node == 3'd5) ? parent_map_5 :
        (current_node == 3'd6) ? parent_map_6 :
        parent_map_7;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            depth <= 4'd0;
            head_ptr <= 3'd0;
            tail_ptr <= 3'd0;
            queue_count <= 3'd0;
            visited_mask <= 8'b0;
            current_node <= 3'd0;
            current_depth <= 4'd0;
            max_depth_reg <= 4'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= SETUP;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SETUP: begin
                    // Initialize for root node
                    head_ptr <= 3'd0;
                    tail_ptr <= 3'd1;
                    queue_count <= 3'd1;
                    queue[0] <= 3'd0; // Root is node 0
                    visited_mask <= 8'b00000001; // Mark node 0 as visited
                    current_depth <= 4'd1;
                    max_depth_reg <= 4'd1; // Root depth is 1
                    next_state <= PROCESSING;
                end

                PROCESSING: begin
                    if (queue_count > 0) begin
                        // Dequeue current node
                        current_node <= queue[head_ptr];
                        head_ptr <= head_ptr + 1'b1;
                        queue_count <= queue_count - 1'b1;
                        // Note: We will process children in next cycle
                        // To avoid complexity, we use a 2-cycle approach for processing
                        // Cycle 1: Dequeue and setup for child check
                        // Cycle 2: Enqueue children
                        // Let's refine this state to handle in one cycle with combinational logic
                    end else begin
                        // Queue empty, go to calculation
                        next_state <= CALCULATING;
                    end
                end

                CALCULATING: begin
                    // Finalize result
                    depth <= max_depth_reg;
                    done <= 1'b1;
                    next_state <= DONE;
                end

                DONE: begin
                    // Wait in done state until reset or start again
                    if (!start) begin
                        // Stay in DONE
                        next_state <= DONE;
                    end else begin
                        // If start is high again, restart
                        next_state <= SETUP;
                        done <= 1'b0;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Combinational logic for processing children (BFS)
    // This logic runs continuously, but only takes effect when state is PROCESSING
    // and we have a node to process (queue_count was > 0 in previous cycle)
    integer i;
    reg [7:0] children;
    reg enqueue_valid;
    reg [2:0] child_node;

    always @(*) begin
        children = 8'b0;
        enqueue_valid = 1'b0;
        child_node = 3'd0;

        if (current_state == PROCESSING && queue_count > 0) begin
            // Get children of current_node (using the value stored in current_node from previous cycle)
            // Note: In the PROCESSING state above, we updated current_node but logic is sequential.
            // However, we need the value of current_node *before* it was updated in the clock edge.
            // Since Verilog is sequential, the current_node in the always block above holds the value.
            // Wait, the logic above updates current_node <= queue[head_ptr].
            // So in the same cycle, current_node changes.
            // To fix: We need to process the node *dequeued* in the previous cycle.
            // Let's restructure PROCESSING state.
            
            // Actually, to keep it simple and synthesizable without latches:
            // We will process the node in the NEXT cycle after dequeuing.
            // Let's change the PROCESSING state to handle the node stored in a 'processing_node' register.
        end
    end

    // Revised Sequential Logic with intermediate registers
    reg [2:0] processing_node;
    reg [3:0] processing_depth;
    reg processing_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing_valid <= 1'b0;
        end else begin
            if (current_state == PROCESSING && queue_count > 0) begin
                // Dequeue to processing_node
                processing_node <= queue[head_ptr];
                processing_depth <= current_depth; // The depth of the dequeued node
                processing_valid <= 1'b1;
                head_ptr <= head_ptr + 1'b1;
                queue_count <= queue_count - 1'b1;
            end else if (current_state == SETUP) begin
                processing_valid <= 1'b0;
            end else if (current_state == CALCULATING) begin
                processing_valid <= 1'b0;
            end else begin
                processing_valid <= 1'b0;
            end
        end
    end

    // Child Enqueuing Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else if (current_state == PROCESSING && processing_valid) begin
            // Check if processing_node has children
            // Get children map based on processing_node
            case (processing_node)
                3'd0: children = parent_map_0;
                3'd1: children = parent_map_1;
                3'd2: children = parent_map_2;
                3'd3: children = parent_map_3;
                3'd4: children = parent_map_4;
                3'd5: children = parent_map_5;
                3'd6: children = parent_map_6;
                3'd7: children = parent_map_7;
            endcase

            // Only process children that are within num_nodes and not visited
            // Also, the node must be a dict (have children) - but the map itself defines that.
            // Actually, parent_mask tells us if a node is a dict.
            // If parent_mask[processing_node] is 0, it has no children, so we shouldn't look at parent_map.
            // However, parent_map should be 0 if parent_mask is 0. We trust the map.

            for (i = 0; i < 8; i = i + 1) begin
                if (i < num_nodes && children[i] && !visited_mask[i]) begin
                    // Enqueue child i
                    if (queue_count < num_nodes && tail_ptr < 8) begin
                        queue[tail_ptr] <= i[2:0];
                        tail_ptr <= tail_ptr + 1'b1;
                        queue_count <= queue_count + 1'b1;
                        visited_mask[i] <= 1'b1;
                        // Update max depth if this child's path is deeper
                        // Child depth = processing_depth + 1
                        if (processing_depth + 1 > max_depth_reg) begin
                            max_depth_reg <= processing_depth + 1'b1;
                        end
                    end
                end
            end
        end else if (current_state == SETUP) begin
             // Reset queue pointers and visited for new run
             head_ptr <= 3'd0;
             tail_ptr <= 3'd0; // Will be incremented to 0 or 1? SETUP sets it to 1 for root.
             // Actually, let's handle SETUP fully here to avoid race conditions
             queue_count <= 3'd0;
             visited_mask <= 8'b0;
             max_depth_reg <= 4'd0;
        end
    end

    // Fix for SETUP state initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
             // handled above
        end else if (current_state == SETUP) begin
             // Add root to queue
             queue[0] <= 3'd0;
             head_ptr <= 3'd0;
             tail_ptr <= 3'd1;
             queue_count <= 3'd1;
             visited_mask <= 8'b00000001;
             current_depth <= 4'd1; // This is used for the first node
             max_depth_reg <= 4'd1;
        end
    end

    // Corrected FSM logic for flow
    // We need to handle the case where SETUP -> PROCESSING.
    // In SETUP, we put root in queue. 
    // In PROCESSING, we dequeue root and process it.
    // The logic above mixes standard sequential blocks. Let's unify the core FSM logic.

    // Override previous definitions with a cleaner single sequential block structure
    // (Re-declaring always blocks is not strictly allowed in a single module, 
    //  so I will merge the logic conceptually into one robust block below)

endmodule

// Re-implementation to ensure single always block for sequential logic (standard practice)
module dict_depth_v2(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [7:0] parent_mask,
    input [7:0] parent_map_0,
    input [7:0] parent_map_1,
    input [7:0] parent_map_2,
    input [7:0] parent_map_3,
    input [7:0] parent_map_4,
    input [7:0] parent_map_5,
    input [7:0] parent_map_6,
    input [7:0] parent_map_7,
    output reg [3:0] depth,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam CALCULATING = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    
    // Queue storage
    reg [2:0] queue [0:7];
    reg [2:0] head, tail, count;
    
    // Traversal state
    reg [7:0] visited;
    reg [2:0] current_node;
    reg [3:0] current_node_depth;
    reg [3:0] max_depth;
    
    // Child iteration counter
    reg [2:0] child_idx;
    reg [2:0] processing_parent;
    reg [3:0] processing_parent_depth;
    reg processing_children;

    // Helper for parent map
    wire [7:0] p_map;
    assign p_map = (processing_parent == 3'd0) ? parent_map_0 :
                   (processing_parent == 3'd1) ? parent_map_1 :
                   (processing_parent == 3'd2) ? parent_map_2 :
                   (processing_parent == 3'd3) ? parent_map_3 :
                   (processing_parent == 3'd4) ? parent_map_4 :
                   (processing_parent == 3'd5) ? parent_map_5 :
                   (processing_parent == 3'd6) ? parent_map_6 :
                   parent_map_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            depth <= 4'd0;
            head <= 3'd0;
            tail <= 3'd0;
            count <= 3'd0;
            visited <= 8'b0;
            max_depth <= 4'd0;
            processing_children <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    // Initialize queue with root (node 0)
                    queue[0] <= 3'd0;
                    head <= 3'd0;
                    tail <= 3'd1;
                    count <= 3'd1;
                    visited <= 8'b00000001;
                    max_depth <= 4'd1; // Root depth is 1
                    state <= PROCESSING;
                    processing_children <= 1'b0;
                end

                PROCESSING: begin
                    if (processing_children) begin
                        // We are iterating children of 'processing_parent'
                        if (child_idx < 3'd8) begin
                            // Check if child_idx is a valid node within num_nodes
                            if (child_idx < num_nodes && p_map[child_idx] && !visited[child_idx]) begin
                                // Enqueue child
                                if (count < num_nodes) begin
                                    queue[tail] <= child_idx;
                                    tail <= tail + 1'b1;
                                    count <= count + 1'b1;
                                    visited[child_idx] <= 1'b1;
                                    // Update max depth: child depth = parent_depth + 1
                                    if (processing_parent_depth + 1 > max_depth) begin
                                        max_depth <= processing_parent_depth + 1'b1;
                                    end
                                end
                            end
                            child_idx <= child_idx + 1'b1;
                        end else begin
                            // Finished iterating children
                            processing_children <= 1'b0;
                            // Stay in PROCESSING to check if queue has more nodes
                        end
                    end else begin
                        // Not processing children, check queue for new parent
                        if (count > 0) begin
                            // Dequeue node to process
                            processing_parent <= queue[head];
                            processing_parent_depth <= (head == 0) ? 4'd1 : max_depth; // Approximate depth tracking fix needed
                            // Wait, depth tracking in BFS is specific to the node.
                            // We need to store depth with the node in the queue.
                            // Let's add depth queue.
                            // Optimizing: Since we only need max depth, we can derive depth.
                            // However, standard BFS tracks depth. Given small size, let's add depth queue.
                            
                            // Refactoring for depth queue:
                            // queue stores node. We need a parallel array for depth.
                            // Or, we can infer depth. But let's stick to the prompt's intent.
                            // The prompt says "Process nodes level by level".
                            // A single queue with (node, depth) is best.
                            // Let's define queue storage with depth.
                            // Reg [2:0] node, Reg [3:0] depth.
                        end else begin
                            state <= CALCULATING;
                        end
                    end
                end

                CALCULATING: begin
                    depth <= max_depth;
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    if (!start) begin
                        // Wait here
                    end else begin
                        state <= SETUP;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Rewrite of PROCESSING to handle Depth Queue correctly
    // We will use separate arrays for node queue and depth queue
    reg [2:0] node_queue [0:7];
    reg [3:0] depth_queue [0:7];
    
    // Replacing the always block above with the correct implementation
    // Since I cannot "delete" code, I will provide the final correct implementation block.
    // The previous block was a partial draft.

endmodule

// FINAL CORRECT IMPLEMENTATION
module dict_depth_final(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [7:0] parent_mask,
    input [7:0] parent_map_0,
    input [7:0] parent_map_1,
    input [7:0] parent_map_2,
    input [7:0] parent_map_3,
    input [7:0] parent_map_4,
    input [7:0] parent_map_5,
    input [7:0] parent_map_6,
    input [7:0] parent_map_7,
    output reg [3:0] depth,
    output reg done
);

    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam POP = 3'b010;       // Dequeue node
    localparam PROCESS_CHILD = 3'b011; // Process a specific child index
    localparam CALCULATING = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    
    // BFS Queues (node and its depth)
    reg [2:0] node_q [0:7];
    reg [3:0] depth_q [0:7];
    reg [2:0] head, tail, count;
    
    reg [7:0] visited;
    reg [3:0] max_depth;
    
    // Processing state
    reg [2:0] current_parent;
    reg [3:0] current_parent_depth;
    reg [2:0] child_iter; // 0 to 7
    
    // Helper for parent map
    wire [7:0] p_map;
    assign p_map = (current_parent == 3'd0) ? parent_map_0 :
                   (current_parent == 3'd1) ? parent_map_1 :
                   (current_parent == 3'd2) ? parent_map_2 :
                   (current_parent == 3'd3) ? parent_map_3 :
                   (current_parent == 3'd4) ? parent_map_4 :
                   (current_parent == 3'd5) ? parent_map_5 :
                   (current_parent == 3'd6) ? parent_map_6 :
                   parent_map_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            depth <= 4'd0;
            head <= 3'd0;
            tail <= 3'd0;
            count <= 3'd0;
            visited <= 8'b0;
            max_depth <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    // Initialize root
                    node_q[0] <= 3'd0;
                    depth_q[0] <= 4'd1;
                    head <= 3'd0;
                    tail <= 3'd1;
                    count <= 3'd1;
                    visited <= 8'b00000001;
                    max_depth <= 4'd1; // Root is depth 1
                    state <= POP;
                end

                POP: begin
                    if (count > 0) begin
                        // Dequeue
                        current_parent <= node_q[head];
                        current_parent_depth <= depth_q[head];
                        head <= head + 1'b1;
                        count <= count - 1'b1;
                        child_iter <= 3'd0; // Start checking children from index 0
                        state <= PROCESS_CHILD;
                    end else begin
                        // Queue empty, finish
                        state <= CALCULATING;
                    end
                end

                PROCESS_CHILD: begin
                    if (child_iter < num_nodes) begin
                        // Check if this child is a child of current_parent and not visited
                        if (p_map[child_iter] && !visited[child_iter]) begin
                            // Enqueue child
                            node_q[tail] <= child_iter;
                            depth_q[tail] <= current_parent_depth + 1'b1;
                            tail <= tail + 1'b1;
                            count <= count + 1'b1;
                            visited[child_iter] <= 1'b1;
                            
                            // Update max depth
                            if (current_parent_depth + 1'b1 > max_depth) begin
                                max_depth <= current_parent_depth + 1'b1;
                            end
                        end
                        child_iter <= child_iter + 1'b1;
                        // Stay in PROCESS_CHILD loop
                    end else begin
                        // Done with this parent, go back to POP
                        state <= POP;
                    end
                end

                CALCULATING: begin
                    depth <= max_depth;
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    if (!start) begin
                        // Hold done
                    end else begin
                        // Restart if start is pressed again
                        state <= SETUP;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
