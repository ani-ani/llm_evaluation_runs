module subway_min_lengths (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [5:0] M,
    input wire [3:0] a [0:31],
    input wire [3:0] b [0:31],
    input wire [15:0] l [0:31],
    input wire l_known [0:31],
    input wire c [0:31],
    output reg [15:0] result,
    output reg [5:0] tunnel_idx,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [5:0] current_tunnel;
    reg [15:0] cable_dist [0:15];
    reg [15:0] result_buffer [0:31];
    reg [5:0] result_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // BFS variables
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [15:0] dist [0:15];
    reg [15:0] visited [0:15];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_tunnel <= 6'd0;
            result <= 16'd0;
            tunnel_idx <= 6'd0;
            done <= 1'b0;
            busy <= 1'b0;
            result_count <= 6'd0;
            cycle_count <= 8'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;

            // Initialize cable_dist and result_buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                cable_dist[i] <= 16'd0;
                dist[i] <= 16'd0;
                visited[i] <= 16'd0;
            end
            for (i = 0; i < 32; i = i + 1) begin
                result_buffer[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        busy <= 1'b1;
                        current_tunnel <= 6'd0;
                        result_count <= 6'd0;
                        cycle_count <= 8'd0;
                    end
                end

                LOAD: begin
                    // Initialize cable graph adjacency matrix
                    integer i, j;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            cable_dist[i][j] <= 16'd0;
                        end
                    end

                    // Load cable edges
                    for (i = 0; i < M; i = i + 1) begin
                        if (c[i]) begin
                            cable_dist[a[i]][b[i]] <= l[i];
                            cable_dist[b[i]][a[i]] <= l[i];
                        end
                    end

                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // BFS to compute distances from station 1 via cables only
                    integer i, j;
                    for (i = 0; i < 16; i = i + 1) begin
                        dist[i] <= 16'd0;
                        visited[i] <= 16'd0;
                    end

                    // Initialize queue
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    queue[0] <= 4'd1;
                    visited[1] <= 16'd1;

                    // BFS loop
                    while (queue_head != queue_tail && cycle_count < MAX_CYCLES) begin
                        reg [3:0] u;
                        u <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;

                        for (i = 0; i < 16; i = i + 1) begin
                            if (cable_dist[u][i] != 16'd0 && !visited[i]) begin
                                dist[i] <= dist[u] + cable_dist[u][i];
                                visited[i] <= 16'd1;
                                queue[queue_tail] <= i;
                                queue_tail <= queue_tail + 4'd1;
                            end
                        end
                    end

                    // Process unknown tunnels
                    for (i = 0; i < M; i = i + 1) begin
                        if (!l_known[i]) begin
                            if (c[i]) begin
                                // Unknown cable edge: minimum length = 1
                                result_buffer[result_count] <= 16'd1;
                            end else begin
                                // Unknown non-cable edge: minimum length = cable distance
                                if (dist[a[i]] != 16'd0 && dist[b[i]] != 16'd0) begin
                                    result_buffer[result_count] <= dist[a[i]] + dist[b[i]];
                                end else begin
                                    result_buffer[result_count] <= 16'd1;
                                end
                            end
                            result_count <= result_count + 6'd1;
                        end
                    end

                    if (result_count == 6'd0) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= OUTPUT;
                        current_tunnel <= 6'd0;
                    end
                end

                OUTPUT: begin
                    if (current_tunnel < result_count) begin
                        result <= result_buffer[current_tunnel];
                        tunnel_idx <= current_tunnel;
                        done <= 1'b1;
                        current_tunnel <= current_tunnel + 6'd1;
                    end else begin
                        done <= 1'b0;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule