module MinMessagesModule(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] enemies,
    input wire [31:0] edges_valid,
    input wire [4:0] edge_src [0:31],
    input wire [4:0] edge_dst [0:31],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BFS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Adjacency matrix (16x16)
    reg [15:0] adj_matrix [0:15];
    reg [15:0] visited;
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] current_node;
    reg [3:0] message_count;
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Initialize adjacency matrix
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            message_count <= 4'd0;
            visited <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                adj_matrix[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Build adjacency matrix from edges
                    for (i = 0; i < 32; i = i + 1) begin
                        if (edges_valid[i]) begin
                            if (!enemies[edge_src[i]] && !enemies[edge_dst[i]]) begin
                                adj_matrix[edge_src[i]][edge_dst[i]] <= 1'b1;
                            end
                        end
                    end
                    state <= BFS;
                end

                BFS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Check if queue is empty
                        if (queue_head == queue_tail) begin
                            // Find next unvisited non-enemy node
                            for (i = 0; i < 16; i = i + 1) begin
                                if (!visited[i] && !enemies[i]) begin
                                    // Start BFS from this node
                                    queue[queue_tail] <= i;
                                    queue_tail <= queue_tail + 4'd1;
                                    visited[i] <= 1'b1;
                                    message_count <= message_count + 4'd1;
                                    break;
                                end
                            end
                            // If no unvisited nodes, finish
                            if (queue_head == queue_tail) begin
                                state <= FINISH;
                            end
                        end else begin
                            // Process queue
                            current_node <= queue[queue_head];
                            queue_head <= queue_head + 4'd1;

                            // Traverse all neighbors
                            for (j = 0; j < 16; j = j + 1) begin
                                if (adj_matrix[current_node][j] && !visited[j] && !enemies[j]) begin
                                    visited[j] <= 1'b1;
                                    queue[queue_tail] <= j;
                                    queue_tail <= queue_tail + 4'd1;
                                end
                            end
                        end
                    end
                end

                FINISH: begin
                    result <= message_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule