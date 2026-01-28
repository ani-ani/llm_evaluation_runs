module max_flow_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] src,
    input wire [2:0] sink,
    input wire edge_valid,
    input wire [2:0] edge_u,
    input wire [2:0] edge_v,
    input wire [7:0] edge_cap,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] BFS = 3'd2;
    localparam [2:0] UPDATE_FLOW = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Residual capacity matrix (8x8)
    reg [7:0] residual [0:7];
    integer i, j;

    // BFS variables
    reg [2:0] queue [0:7];
    reg [2:0] parent [0:7];
    reg [7:0] queue_head, queue_tail;
    reg [7:0] visited [0:7];

    // Path and flow variables
    reg [2:0] path [0:7];
    reg [7:0] path_length;
    reg [7:0] bottleneck;
    reg [15:0] total_flow;

    // Iteration counter
    reg [7:0] iteration_count;
    localparam [7:0] MAX_ITERATIONS = 8'd256;

    // Edge loading counter
    reg [3:0] edge_count;
    localparam [3:0] MAX_EDGES = 4'd16;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            total_flow <= 16'd0;
            iteration_count <= 8'd0;
            edge_count <= 4'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            path_length <= 8'd0;
            bottleneck <= 8'd0;

            // Initialize residual matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    residual[i][j] <= 8'd0;
                end
            end

            // Initialize BFS variables
            for (i = 0; i < 8; i = i + 1) begin
                queue[i] <= 3'd0;
                parent[i] <= 3'd0;
                visited[i] <= 8'd0;
                path[i] <= 3'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Edge loading logic
    always @(posedge clk) begin
        if (state == LOAD_EDGES && edge_valid && edge_count < MAX_EDGES) begin
            residual[edge_u][edge_v] <= edge_cap;
            edge_count <= edge_count + 4'd1;
        end
    end

    // Main FSM logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = LOAD_EDGES;
                    edge_count <= 4'd0;
                    total_flow <= 16'd0;
                    iteration_count <= 8'd0;
                end
            end

            LOAD_EDGES: begin
                if (edge_count >= MAX_EDGES || !edge_valid) begin
                    next_state = BFS;
                end
            end

            BFS: begin
                // Initialize BFS
                queue_head <= 8'd0;
                queue_tail <= 8'd1;
                queue[0] <= src;
                for (i = 0; i < 8; i = i + 1) begin
                    visited[i] <= 8'd0;
                    parent[i] <= 3'd0;
                end
                visited[src] <= 8'd1;
                parent[src] <= 3'd0;

                // Run BFS
                reg found;
                found = 1'b0;
                for (i = 0; i < 8 && !found; i = i + 1) begin
                    if (queue_head < queue_tail) begin
                        reg [2:0] current;
                        current = queue[queue_head];
                        queue_head = queue_head + 8'd1;

                        for (j = 0; j < 8; j = j + 1) begin
                            if (residual[current][j] > 8'd0 && !visited[j]) begin
                                visited[j] <= 8'd1;
                                parent[j] <= current;
                                queue[queue_tail] <= j;
                                queue_tail = queue_tail + 8'd1;

                                if (j == sink) begin
                                    found = 1'b1;
                                end
                            end
                        end
                    end
                end

                // Check if path found
                if (visited[sink]) begin
                    // Find bottleneck
                    bottleneck = 8'd255;
                    reg [2:0] current_node;
                    current_node = sink;
                    path_length = 8'd0;

                    while (current_node != src) begin
                        path[path_length] = current_node;
                        path_length = path_length + 8'd1;
                        current_node = parent[current_node];
                        if (residual[current_node][path[path_length - 8'd1]] < bottleneck) begin
                            bottleneck = residual[current_node][path[path_length - 8'd1]];
                        end
                    end

                    next_state = UPDATE_FLOW;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            UPDATE_FLOW: begin
                // Update residual capacities
                reg [2:0] u, v;
                u = src;
                for (i = 0; i < path_length; i = i + 1) begin
                    v = path[i];
                    residual[u][v] = residual[u][v] - bottleneck;
                    residual[v][u] = residual[v][u] + bottleneck;
                    u = v;
                end

                // Accumulate flow
                total_flow = total_flow + bottleneck;
                iteration_count = iteration_count + 8'd1;

                if (iteration_count >= MAX_ITERATIONS) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = BFS;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                result <= total_flow;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule