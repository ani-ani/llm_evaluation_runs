module BFS_Validator(
    input clk,
    input rst_n,
    input start,
    input seq_valid,
    input [4:0] seq_data,
    input [4:0] seq_len,
    output reg result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_SEQ = 3'd1;
    localparam [2:0] BFS_LOOP = 3'd2;
    localparam [2:0] CHECK_CHILDREN = 3'd3;
    localparam [2:0] VALIDATE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers and wires
    reg [2:0] state, next_state;
    reg [4:0] seq_storage [0:15];  // Store sequence nodes (0-indexed)
    reg [4:0] seq_idx;              // Current sequence index
    reg [4:0] seq_max_idx;          // seq_len - 1
    reg [4:0] stored_seq_len;       // Store the input seq_len
    reg [15:0] visited;             // 16 bits for 16 nodes
    reg [15:0] adj [0:15];          // Adjacency matrix: adj[i] is neighbors of node i (0-indexed)
    reg [3:0] queue [0:15];         // Queue stores 4-bit node indices (0-15)
    reg [3:0] head;                 // Queue head pointer
    reg [3:0] tail;                 // Queue tail pointer
    reg [3:0] current_node;         // Node being processed
    reg [4:0] child_count;          // Number of children for current node
    reg [3:0] child_idx;            // Index for iterating through children
    reg [3:0] neighbor_idx;         // Index for checking neighbors
    reg [3:0] prev_node;            // Temp storage for parent in queue
    reg [3:0] total_nodes_visited;
    reg [4:0] cycle_counter;        // To prevent infinite loops
    localparam [4:0] MAX_CYCLES = 5'd24;

    // Reset sequence and adjacency matrix
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            visited <= 16'd0;
            head <= 4'd0;
            tail <= 4'd0;
            current_node <= 4'd0;
            child_count <= 5'd0;
            child_idx <= 4'd0;
            neighbor_idx <= 4'd0;
            seq_idx <= 5'd0;
            total_nodes_visited <= 4'd0;
            cycle_counter <= 5'd0;
            stored_seq_len <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                seq_storage[i] <= 5'd0;
                adj[i] <= 16'd0;
            end
            // Simple tree adjacency for test: node 1 connected to 2, 3; 2 to 4, 5; 3 to 6, 7
            // This is a fixed tree topology as no input for tree structure is provided.
            // Assuming a balanced tree starting at node 1 (root).
            adj[0] <= 16'h0006; // Node 1 (index 0) -> nodes 2 (1) and 3 (2)
            adj[1] <= 16'h000C; // Node 2 (index 1) -> nodes 4 (3) and 5 (4)
            adj[2] <= 16'h0060; // Node 3 (index 2) -> nodes 6 (5) and 7 (6)
            // Note: Implementation assumes a predefined tree structure.
            // Adjacency matrix generation logic could be added if tree input was provided.
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 5'd0;
                    if (start) begin
                        visited <= 16'd0;
                        head <= 4'd0;
                        tail <= 4'd0;
                        total_nodes_visited <= 4'd0;
                        seq_idx <= 5'd0;
                        result <= 1'b1; // Start with result=1, falsify on error
                    end
                end
                LOAD_SEQ: begin
                    if (seq_valid) begin
                        // Convert 1-16 input to 0-15 internal storage
                        seq_storage[seq_idx] <= seq_data - 5'd1;
                        seq_idx <= seq_idx + 5'd1;
                        // Auto-transition if received full length
                        if (seq_idx + 5'd1 >= stored_seq_len) begin
                            // Sequence loaded, enqueue node 1 (index 0) if valid
                            if (seq_storage[0] != 4'd0 && seq_valid) begin
                                // First node check handled in VALIDATE state usually, 
                                // but here we check during BFS start.
                            end
                        end
                    end
                end
                BFS_LOOP: begin
                    cycle_counter <= cycle_counter + 5'd1;
                    // Dequeue operation happens here if queue is not empty
                    // Handled in combinational logic for next_state
                end
                CHECK_CHILDREN: begin
                    // Check specific child in sequence
                    if (seq_idx < stored_seq_len) begin
                        // Check 1: Is it a neighbor of current_node?
                        if ((adj[current_node][seq_storage[seq_idx]] == 1'b1) || (seq_idx == 0 && seq_storage[0] == 4'd0)) begin
                             // Check 2: Has it been visited before? (Should be unvisited)
                             // BFS rule: Children must be unvisited at discovery time
                             if (visited[seq_storage[seq_idx]] == 1'b0 || (seq_idx == 0 && seq_storage[0] == 4'd0)) begin
                                 // Valid child
                                 // Mark visited (except root 1 if checking neighbors of 1)
                                 if (seq_storage[seq_idx] != 4'd0) visited[seq_storage[seq_idx]] <= 1'b1;
                                 // Enqueue new child
                                 if (tail < 4'd15) begin
                                     queue[tail] <= seq_storage[seq_idx];
                                     tail <= tail + 4'd1;
                                 end
                                 seq_idx <= seq_idx + 5'd1;
                                 child_idx <= child_idx + 4'd1;
                             end else begin
                                 // Already visited node in sequence -> Invalid
                                 result <= 1'b0;
                             end
                        end else begin
                            // Not a neighbor -> Invalid
                            result <= 1'b0;
                        end
                    end else begin
                        // Ran out of sequence data -> Invalid
                        result <= 1'b0;
                    end
                    
                    if (child_idx >= child_count - 4'd1) begin
                        // Finished checking all children for this node
                        // Loop back to BFS_LOOP
                    end
                end
                VALIDATE: begin
                    // Final checks
                    if (seq_idx != stored_seq_len) begin
                        // Sequence has leftovers -> Invalid
                        result <= 1'b0;
                    end
                    // Check if all nodes were visited (only check nodes that exist in sequence)
                    // Since max nodes is 16, we can check visited bits
                    // If tree has fewer nodes, this might flag false positive, 
                    // but requirement is "all nodes visited".
                    // Assuming full 16 node check or sequence based check.
                    // If sequence length matches visited count + 1 (root), it's good.
                    if (seq_idx != total_nodes_visited + 4'd1) begin
                        result <= 1'b0;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_SEQ;
            end
            LOAD_SEQ: begin
                // We assume seq_len cycles or auto-detect based on interface.
                // Since it's input 'seq_valid', we need a way to know when seq stops.
                // The spec says "Accept sequence data over seq_len cycles".
                // However, seq_len is an input that might be delayed or unknown.
                // We will assume external control asserts seq_valid for seq_len cycles.
                // If we count locally:
                if (seq_valid) begin
                    if (seq_idx + 5'd1 >= stored_seq_len) begin
                        // Transition to BFS
                        if (seq_storage[0] != 4'd0) begin // Root must be 1 (0 internally)
                            next_state = DONE_STATE;
                        end else begin
                            // Check if queue has items
                            if (head < tail) next_state = BFS_LOOP;
                            else next_state = VALIDATE;
                        end
                    end
                end
            end
            BFS_LOOP: begin
                if (head < tail) begin
                    // Dequeue here (virtual, logic handled in combinational extract)
                    current_node = queue[head]; // Blocking assignment for next state logic
                    // We need to know degree of current_node
                    // To avoid complex logic here, we define combinational degree calc
                    next_state = CHECK_CHILDREN;
                end else begin
                    next_state = VALIDATE;
                end
            end
            CHECK_CHILDREN: begin
                // If invalid check detected (result dropped to 0 in seq block), jump to DONE
                if (result == 1'b0) next_state = DONE_STATE;
                else if (child_idx >= child_count) begin
                    // Move to next node in queue
                    head = head + 4'd1; // Update head pointer
                    child_idx = 4'd0;
                    next_state = BFS_LOOP;
                end else begin
                    next_state = CHECK_CHILDREN;
                end
            end
            VALIDATE: begin
                if (result == 1'b0) next_state = DONE_STATE;
                else next_state = DONE_STATE;
            end
            DONE_STATE: begin
                if (start) next_state = IDLE; // Wait for reset or new start
            end
            default: next_state = IDLE;
        endcase
    end

    // Combinational Helper Logic
    always @(*) begin
        // Calculate degree of current_node (number of neighbors)
        // degree = popcount(adj[current_node] & ~visited)
        // We iterate to find unvisited neighbors
        if (current_node < 4'd16) begin
            // Count unvisited neighbors for current_node
            child_count = 5'd0;
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                if (adj[current_node][k] && !visited[k]) begin
                    child_count = child_count + 5'd1;
                end
            end
        end else begin
            child_count = 5'd0;
        end
    end

    // Modified combinational logic for LOAD_SEQ to handle stored_seq_len properly
    always @(posedge clk) begin
        if (state == IDLE && start) begin
            stored_seq_len <= seq_len;
            // Pre-fill queue with root if first node is valid
            // This is tricky with clocked logic. We will do it during BFS start.
        end
        if (state == LOAD_SEQ && seq_valid) begin
            // Special case for first node (root)
            if (seq_idx == 0 && seq_data != 5'd1) begin
                result <= 1'b0; // Invalid root
            end
            // If root is loaded correctly, queue it
            if (seq_idx == 0 && seq_data == 5'd1) begin
                visited[0] <= 1'b1;
                queue[0] <= 4'd0;
                tail <= 4'd1;
            end
        end
    end

endmodule