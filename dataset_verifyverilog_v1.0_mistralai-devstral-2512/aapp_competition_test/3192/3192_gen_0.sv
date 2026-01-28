module cycle_detector(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [255:0] adj_matrix,
    output reg result_valid,
    output reg ship_it,
    output reg [79:0] cycle_nodes,
    output reg [4:0] cycle_length,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Adjacency matrix storage (16x16)
    reg [15:0] adj_reg [0:15];

    // BFS state
    reg [3:0] current_node;
    reg [3:0] start_node;
    reg [3:0] bfs_queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] parent [0:15];
    reg [3:0] distance [0:15];
    reg [3:0] cycle_start, cycle_end;
    reg [3:0] min_cycle_length;
    reg [3:0] cycle_nodes_reg [0:15];

    // Control signals
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result_valid <= 1'b0;
            ship_it <= 1'b0;
            done <= 1'b0;
            cycle_length <= 5'd0;
            cycle_nodes <= 80'd0;
            cycle_count <= 8'd0;

            // Initialize adjacency matrix
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                adj_reg[i] <= 16'd0;
            end

            // Initialize BFS state
            current_node <= 4'd0;
            start_node <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            cycle_start <= 4'd0;
            cycle_end <= 4'd0;
            min_cycle_length <= 4'd16;

            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= 4'd0;
                distance[i] <= 4'd0;
                bfs_queue[i] <= 4'd0;
                cycle_nodes_reg[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Load adjacency matrix from input
    always @(posedge clk) begin
        if (state == IDLE && start) begin
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    adj_reg[i][j] <= adj_matrix[i*16 + j];
                end
            end
        end
    end

    // Main state machine logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= PROCESS;
                        cycle_count <= 8'd0;
                        start_node <= 4'd0;
                        min_cycle_length <= 4'd16;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // BFS from current start_node
                    if (start_node < n && start_node < 16) begin
                        // Initialize BFS
                        if (current_node == 4'd0) begin
                            integer i;
                            for (i = 0; i < 16; i = i + 1) begin
                                parent[i] <= 4'd0;
                                distance[i] <= 4'd0;
                            end
                            queue_head <= 4'd0;
                            queue_tail <= 4'd0;
                            bfs_queue[0] <= start_node;
                            queue_tail <= 4'd1;
                            parent[start_node] <= 4'd0;
                            distance[start_node] <= 4'd0;
                            current_node <= start_node;
                        end

                        // Process BFS queue
                        if (queue_head < queue_tail) begin
                            current_node <= bfs_queue[queue_head];
                            queue_head <= queue_head + 4'd1;

                            // Check neighbors
                            integer j;
                            for (j = 0; j < 16; j = j + 1) begin
                                if (adj_reg[current_node][j] && j < n) begin
                                    // Found cycle
                                    if (parent[current_node] != 4'd0 && j == start_node) begin
                                        reg [3:0] temp_length;
                                        temp_length <= distance[current_node] + 4'd1;

                                        // Update minimum cycle
                                        if (temp_length < min_cycle_length) begin
                                            min_cycle_length <= temp_length;
                                            cycle_start <= start_node;
                                            cycle_end <= current_node;

                                            // Reconstruct cycle path
                                            integer k;
                                            reg [3:0] temp_node;
                                            temp_node <= current_node;
                                            for (k = 0; k < 16; k = k + 1) begin
                                                cycle_nodes_reg[k] <= 5'd0;
                                            end
                                            for (k = temp_length - 1; k >= 0; k = k - 1) begin
                                                cycle_nodes_reg[k] <= temp_node;
                                                temp_node <= parent[temp_node];
                                            end
                                        end
                                    end
                                    // Add to queue if not visited
                                    else if (parent[j] == 4'd0) begin
                                        parent[j] <= current_node;
                                        distance[j] <= distance[current_node] + 4'd1;
                                        bfs_queue[queue_tail] <= j;
                                        queue_tail <= queue_tail + 4'd1;
                                    end
                                end
                            end

                            // Move to next node if queue empty
                            if (queue_head >= queue_tail) begin
                                start_node <= start_node + 4'd1;
                                current_node <= 4'd0;
                            end
                        end

                        // Check if done with all nodes
                        if (start_node >= n || start_node >= 16 || cycle_count >= MAX_CYCLES) begin
                            if (min_cycle_length < 16) begin
                                next_state <= OUTPUT;
                            end else begin
                                next_state <= OUTPUT;
                            end
                        end
                    end else begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    if (min_cycle_length < 16) begin
                        result_valid <= 1'b1;
                        ship_it <= 1'b0;
                        cycle_length <= min_cycle_length;

                        // Pack cycle_nodes output
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            cycle_nodes[(i*5)+4:(i*5)] <= cycle_nodes_reg[i];
                        end
                    end else begin
                        result_valid <= 1'b0;
                        ship_it <= 1'b1;
                        cycle_length <= 5'd0;
                        cycle_nodes <= 80'd0;
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Clear done after one cycle
    always @(posedge clk) begin
        if (state != DONE_STATE) begin
            done <= 1'b0;
        end
    end

endmodule