module AirportBFS(
    input clk,
    input rst_n,
    input start,
    input [3:0] s,
    input [3:0] t,
    input [15:0] type,
    input [3:0] len [0:15],
    input [63:0] list [0:15],
    output reg [4:0] result,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BFS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // BFS queue (FIFO)
    reg [3:0] queue [0:15];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] queue_size;

    // Distance array
    reg [4:0] distance [0:15];

    // Adjacency matrix
    reg [15:0] adj_matrix [0:15];

    // Current node being processed
    reg [3:0] current_node;
    reg [3:0] neighbor_idx;
    reg [3:0] neighbor;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_size <= 4'd0;
            current_node <= 4'd0;
            neighbor_idx <= 4'd0;
            neighbor <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            result <= 5'd0;

            // Initialize distance array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                distance[i] <= 5'd16;
            end

            // Initialize adjacency matrix
            integer j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    adj_matrix[i][j] <= 1'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        cycle_count <= 8'd0;
                    end
                end

                INIT: begin
                    // Build adjacency matrix
                    integer i, j;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (type[i] == 1'b0) begin
                            // Type N: direct adjacency
                            for (j = 0; j < len[i]; j = j + 1) begin
                                adj_matrix[i][list[i][j*4+3:j*4]] <= 1'b1;
                            end
                        end else begin
                            // Type C: complement adjacency
                            for (j = 0; j < 16; j = j + 1) begin
                                adj_matrix[i][j] <= 1'b1;
                            end
                            for (j = 0; j < len[i]; j = j + 1) begin
                                adj_matrix[i][list[i][j*4+3:j*4]] <= 1'b0;
                            end
                        end
                    end

                    // Initialize BFS
                    distance[s] <= 5'd0;
                    queue[0] <= s;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd1;
                    queue_size <= 4'd1;
                    current_node <= s;
                    neighbor_idx <= 4'd0;
                    state <= BFS;
                end

                BFS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Process current node
                    if (neighbor_idx == 4'd0) begin
                        // Get next node from queue
                        if (queue_size > 4'd0) begin
                            current_node <= queue[queue_head];
                            queue_head <= queue_head + 4'd1;
                            queue_size <= queue_size - 4'd1;
                        end else begin
                            // Queue empty, BFS complete
                            state <= FINISH;
                        end
                    end

                    // Explore neighbors
                    if (neighbor_idx < 4'd16) begin
                        if (adj_matrix[current_node][neighbor_idx] == 1'b1) begin
                            // Valid neighbor
                            if (distance[neighbor_idx] == 5'd16) begin
                                // Not visited yet
                                distance[neighbor_idx] <= distance[current_node] + 5'd1;
                                queue[queue_tail] <= neighbor_idx;
                                queue_tail <= queue_tail + 4'd1;
                                queue_size <= queue_size + 4'd1;
                            end
                        end
                        neighbor_idx <= neighbor_idx + 4'd1;
                    end else begin
                        neighbor_idx <= 4'd0;
                    end

                    // Check for timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Check if target was reached
                    if (distance[t] < 5'd16) begin
                        valid <= 1'b1;
                        result <= distance[t];
                    end else begin
                        valid <= 1'b0;
                        result <= 5'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule