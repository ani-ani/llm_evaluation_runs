module BipartiteMatching(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [5:0] num_edges,
    input wire [63:0] edge_u,
    input wire [63:0] edge_v,
    input wire [63:0] capacity,
    output reg [3:0] max_flow,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] INIT    = 4'd1;
    localparam [3:0] BUILD   = 4'd2;
    localparam [3:0] SEARCH  = 4'd3;
    localparam [3:0] AUGMENT = 4'd4;
    localparam [3:0] UPDATE  = 4'd5;
    localparam [3:0] DONE    = 4'd6;

    reg [3:0] state;
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd4096;

    // Residual graph: 16x16 bit matrix
    reg [15:0] residual [0:15];
    integer i, j;

    // BFS queue and tracking
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] parent [0:15];
    reg [15:0] visited;

    // Path tracking
    reg [3:0] current_node;
    reg [3:0] path [0:15];
    reg [3:0] path_length;

    // Edge processing
    reg [5:0] edge_index;
    reg [3:0] u_node, v_node;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_flow <= 4'd0;
            done <= 1'b0;
            cycle_count <= 12'd0;
            edge_index <= 6'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            path_length <= 4'd0;
            current_node <= 4'd0;
            visited <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                residual[i] <= 16'd0;
                parent[i] <= 4'd0;
                path[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 12'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    for (i = 0; i < 16; i = i + 1) begin
                        residual[i] <= 16'd0;
                    end
                    state <= BUILD;
                end

                BUILD: begin
                    if (edge_index < num_edges) begin
                        u_node = edge_u[(edge_index << 2) +: 4];
                        v_node = edge_v[(edge_index << 2) +: 4];
                        if (u_node < 16 && v_node < 16) begin
                            residual[u_node][v_node] <= 1'b1;
                        end
                        edge_index <= edge_index + 6'd1;
                    end else begin
                        edge_index <= 6'd0;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    // BFS initialization
                    if (cycle_count == 12'd0) begin
                        visited <= 16'd0;
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            parent[i] <= 4'd0;
                        end
                        queue[queue_tail] <= 4'd0; // Start from source
                        queue_tail <= queue_tail + 4'd1;
                        visited[0] <= 1'b1;
                        parent[0] <= 4'd0;
                    end

                    // BFS processing
                    if (queue_head < queue_tail) begin
                        current_node = queue[queue_head];
                        queue_head <= queue_head + 4'd1;

                        // Check all neighbors
                        for (j = 0; j < 16; j = j + 1) begin
                            if (residual[current_node][j] && !visited[j]) begin
                                visited[j] <= 1'b1;
                                parent[j] <= current_node;
                                queue[queue_tail] <= j;
                                queue_tail <= queue_tail + 4'd1;

                                // Check if sink reached
                                if (j == 4'd15) begin
                                    state <= AUGMENT;
                                end
                            end
                        end
                    end else begin
                        // No path found
                        state <= DONE;
                    end

                    cycle_count <= cycle_count + 12'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                AUGMENT: begin
                    // Reconstruct path
                    path_length <= 4'd0;
                    current_node <= 4'd15;
                    while (current_node != 4'd0) begin
                        path[path_length] <= current_node;
                        path_length <= path_length + 4'd1;
                        current_node <= parent[current_node];
                    end
                    path[path_length] <= 4'd0;
                    path_length <= path_length + 4'd1;

                    // Update residual graph
                    for (i = 0; i < path_length; i = i + 1) begin
                        u_node = path[i];
                        v_node = path[i + 1];
                        residual[u_node][v_node] <= 1'b0;
                        residual[v_node][u_node] <= 1'b1;
                    end

                    state <= UPDATE;
                end

                UPDATE: begin
                    max_flow <= max_flow + 4'd1;
                    state <= SEARCH;
                    cycle_count <= 12'd0;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule