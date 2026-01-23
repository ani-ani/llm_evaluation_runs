module max_flow_solver (
    input clk,
    input rst_n,
    input start,
    input [1:0] source,
    input [1:0] sink,
    input [1:0] num_nodes,
    input [5:0] edge_count,
    input [15:0] capacity [0:3][0:3],
    output reg [15:0] max_flow,
    output reg [5:0] used_edges,
    output reg [1:0] out_u,
    output reg [1:0] out_v,
    output reg [15:0] out_flow,
    output reg out_valid,
    output reg done
);

    // Internal state definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        BFS_SEARCH,
        AUGMENT,
        OUTPUT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Residual capacity matrix
    reg [15:0] residual [0:3][0:3];

    // BFS structures
    reg [1:0] parent [0:3];
    reg [3:0] visited;
    reg [1:0] queue [0:3];
    reg [1:0] queue_head, queue_tail;
    reg [1:0] current_node;
    reg [1:0] path [0:3];
    reg [1:0] path_length;

    // Augmenting path variables
    reg [15:0] bottleneck;
    reg [1:0] u, v;

    // Output edge tracking
    reg [5:0] edge_counter;
    reg [1:0] edge_u, edge_v;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            max_flow <= 0;
            used_edges <= 0;
            out_u <= 0;
            out_v <= 0;
            out_flow <= 0;
            out_valid <= 0;
            done <= 0;
            edge_counter <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            path_length <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = BFS_SEARCH;
            end
            BFS_SEARCH: begin
                if (visited[sink]) next_state = AUGMENT;
                else if (queue_head == queue_tail) next_state = OUTPUT;
            end
            AUGMENT: begin
                next_state = BFS_SEARCH;
            end
            OUTPUT: begin
                if (edge_counter == edge_count) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // State actions
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (current_state)
                INIT: begin
                    // Initialize residual graph
                    for (int i = 0; i < 4; i++) begin
                        for (int j = 0; j < 4; j++) begin
                            residual[i][j] <= capacity[i][j];
                        end
                    end
                    max_flow <= 0;
                    used_edges <= 0;
                    edge_counter <= 0;
                end

                BFS_SEARCH: begin
                    // BFS implementation
                    if (queue_head < queue_tail) begin
                        current_node = queue[queue_head];
                        queue_head = queue_head + 1;
                        for (int v = 0; v < num_nodes; v++) begin
                            if (!visited[v] && residual[current_node][v] > 0) begin
                                visited[v] = 1;
                                parent[v] = current_node;
                                queue[queue_tail] = v;
                                queue_tail = queue_tail + 1;
                            end
                        end
                    end else begin
                        // Reset for next BFS
                        visited = 4'b0000;
                        queue_head = 0;
                        queue_tail = 0;
                        visited[source] = 1;
                        queue[0] = source;
                        queue_tail = 1;
                    end
                end

                AUGMENT: begin
                    // Find bottleneck capacity
                    bottleneck = residual[sink][parent[sink]];
                    u = sink;
                    while (u != source) begin
                        v = parent[u];
                        if (residual[v][u] < bottleneck) begin
                            bottleneck = residual[v][u];
                        end
                        u = v;
                    end

                    // Update residual capacities
                    u = sink;
                    while (u != source) begin
                        v = parent[u];
                        residual[v][u] = residual[v][u] - bottleneck;
                        residual[u][v] = residual[u][v] + bottleneck;
                        u = v;
                    end

                    // Update max flow
                    max_flow = max_flow + bottleneck;

                    // Reset BFS structures
                    visited = 4'b0000;
                    queue_head = 0;
                    queue_tail = 0;
                end

                OUTPUT: begin
                    // Output edges with positive flow
                    if (edge_counter < edge_count) begin
                        edge_u = edge_counter[5:4];
                        edge_v = edge_counter[3:2];
                        out_flow = capacity[edge_u][edge_v] - residual[edge_u][edge_v];
                        if (out_flow > 0) begin
                            out_u = edge_u;
                            out_v = edge_v;
                            out_valid = 1;
                            used_edges = used_edges + 1;
                        end else begin
                            out_valid = 0;
                        end
                        edge_counter = edge_counter + 1;
                    end
                end

                DONE: begin
                    done = 1;
                    out_valid = 0;
                end
            endcase
        end
    end

    // Default assignments
    always @(*) begin
        out_u = 0;
        out_v = 0;
        out_flow = 0;
        out_valid = 0;
        done = 0;
    end

endmodule