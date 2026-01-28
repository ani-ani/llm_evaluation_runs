module BFSValidator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire seq_valid,
    input wire [4:0] seq_data,
    input wire [4:0] seq_len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_SEQ = 3'd1;
    localparam [2:0] BFS_LOOP = 3'd2;
    localparam [2:0] VALIDATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Sequence storage (max 16 nodes)
    reg [4:0] sequence [0:15];
    reg [4:0] seq_index;
    reg [4:0] seq_count;

    // Adjacency matrix (16x16 bits)
    reg [15:0] adj [0:15];

    // BFS queue (depth 16)
    reg [4:0] queue [0:15];
    reg [3:0] head, tail;

    // Visited array (16 bits)
    reg [15:0] visited;

    // Current node and degree
    reg [4:0] current_node;
    reg [3:0] degree;

    // Temporary registers
    reg [4:0] temp_node;
    reg [4:0] i, j;
    reg [3:0] unvisited_count;
    reg [4:0] next_nodes [0:15];

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            seq_index <= 5'd0;
            seq_count <= 5'd0;
            head <= 4'd0;
            tail <= 4'd0;
            current_node <= 5'd0;
            degree <= 4'd0;
            cycle_count <= 8'd0;

            // Initialize sequence array
            for (i = 0; i < 16; i = i + 1) begin
                sequence[i] <= 5'd0;
            end

            // Initialize adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
            end

            // Initialize queue
            for (i = 0; i < 16; i = i + 1) begin
                queue[i] <= 5'd0;
            end

            // Initialize visited array
            visited <= 16'd0;

            // Initialize next_nodes array
            for (i = 0; i < 16; i = i + 1) begin
                next_nodes[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in reset
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD_SEQ;
                        seq_index <= 5'd0;
                        seq_count <= 5'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_SEQ: begin
                    if (seq_valid) begin
                        sequence[seq_index] <= seq_data - 5'd1; // Convert to 0-indexed
                        seq_index <= seq_index + 5'd1;
                        seq_count <= seq_count + 5'd1;
                        if (seq_index == seq_len) begin
                            next_state <= BFS_LOOP;
                            // Initialize BFS
                            head <= 4'd0;
                            tail <= 4'd1;
                            queue[0] <= 5'd0; // Node 1 is 0-indexed
                            visited[0] <= 1'b1;
                            current_node <= 5'd0;
                        end
                    end else begin
                        next_state <= LOAD_SEQ;
                    end
                end

                BFS_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        next_state <= DONE_STATE;
                    end else if (head == tail) begin
                        // Queue empty, check if all nodes processed
                        next_state <= VALIDATE;
                    end else begin
                        // Dequeue current node
                        current_node <= queue[head];
                        head <= head + 4'd1;

                        // Count unvisited neighbors
                        unvisited_count <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (adj[current_node][i] && !visited[i]) begin
                                next_nodes[unvisited_count] <= i;
                                unvisited_count <= unvisited_count + 4'd1;
                            end
                        end

                        degree <= unvisited_count;

                        // Check if next degree nodes in sequence match unvisited neighbors
                        if (seq_count < seq_len) begin
                            reg [4:0] next_seq_index;
                            reg match;
                            next_seq_index <= seq_count;
                            match <= 1'b1;

                            for (i = 0; i < degree; i = i + 1) begin
                                if (next_seq_index < seq_len) begin
                                    if (sequence[next_seq_index] != next_nodes[i]) begin
                                        match <= 1'b0;
                                    end
                                    next_seq_index <= next_seq_index + 5'd1;
                                end else begin
                                    match <= 1'b0;
                                end
                            end

                            if (match) begin
                                // Mark nodes as visited and enqueue
                                for (i = 0; i < degree; i = i + 1) begin
                                    if (seq_count < seq_len) begin
                                        temp_node <= sequence[seq_count];
                                        visited[temp_node] <= 1'b1;
                                        queue[tail] <= temp_node;
                                        tail <= tail + 4'd1;
                                        seq_count <= seq_count + 5'd1;
                                    end
                                end
                            end else begin
                                result <= 1'b0;
                                next_state <= DONE_STATE;
                            end
                        end else begin
                            result <= 1'b0;
                            next_state <= DONE_STATE;
                        end
                    end
                end

                VALIDATE: begin
                    // Check if all nodes in sequence are visited and sequence is complete
                    if (seq_count == seq_len) begin
                        reg all_visited;
                        all_visited <= 1'b1;
                        for (i = 0; i < seq_len; i = i + 1) begin
                            if (!visited[sequence[i]]) begin
                                all_visited <= 1'b0;
                            end
                        end
                        result <= all_visited;
                    end else begin
                        result <= 1'b0;
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

    // Initialize adjacency matrix (example tree structure)
    // This should be replaced with actual tree configuration
    // For now, we'll initialize a simple tree where node 1 (0) is connected to nodes 2-4 (1-3)
    // and node 2 (1) is connected to nodes 5-6 (4-5), etc.
    initial begin
        // Node 0 (1) connections
        adj[0] = 16'b0000000000001110; // Connected to nodes 1,2,3 (indices 1,2,3)
        // Node 1 (2) connections
        adj[1] = 16'b0000000000010001; // Connected to node 0 and nodes 4,5 (indices 4,5)
        // Node 2 (3) connections
        adj[2] = 16'b0000000000100001; // Connected to node 0 and node 6 (index 6)
        // Node 3 (4) connections
        adj[3] = 16'b0000000001000001; // Connected to node 0 and node 7 (index 7)
        // Other nodes have minimal connections for this example
        for (i = 4; i < 16; i = i + 1) begin
            adj[i] = 16'd0;
        end
    end

endmodule