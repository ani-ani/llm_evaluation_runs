module graph_orientation_4bit(
    input clk,
    input rst_n,
    input start,
    input [2:0] m,
    input [7:0] edge_0,
    input [7:0] edge_1,
    input [7:0] edge_2,
    input [7:0] edge_3,
    output reg yes_no,
    output reg [7:0] orient_0,
    output reg [7:0] orient_1,
    output reg [7:0] orient_2,
    output reg [7:0] orient_3,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK_START = 4'd1;
    localparam [3:0] BUILD_ORIENT = 4'd2;
    localparam [3:0] FLOYD_INIT = 4'd3;
    localparam [3:0] FLOYD_K_LOOP = 4'd4;
    localparam [3:0] FLOYD_IJ_LOOP = 4'd5;
    localparam [3:0] CHECK_STRONG = 4'd6;
    localparam [3:0] NEXT_ORIENT = 4'd7;
    localparam [3:0] OUTPUT = 4'd8;
    localparam [3:0] DONE_STATE = 4'd9;

    reg [3:0] state, next_state;

    // Edge storage
    reg [3:0] u [0:3], v [0:3];

    // Orientation tracking
    reg [2:0] orient_count;
    reg [2:0] max_orient;
    reg [3:0] from [0:3], to [0:3];

    // Floyd-Warshall variables
    reg [3:0] dist [0:3][0:3];
    reg [1:0] k, i, j;
    reg [3:0] temp_dist;

    // Strong connectivity check
    reg [3:0] reachable;
    reg strong_connected;

    // Cycle counter for timeout
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            yes_no <= 1'b0;
            orient_0 <= 8'd0;
            orient_1 <= 8'd0;
            orient_2 <= 8'd0;
            orient_3 <= 8'd0;
            done <= 1'b0;
            orient_count <= 3'd0;
            max_orient <= 3'd0;
            cycle_count <= 10'd0;

            // Initialize edge storage
            u[0] <= 4'd0; v[0] <= 4'd0;
            u[1] <= 4'd0; v[1] <= 4'd0;
            u[2] <= 4'd0; v[2] <= 4'd0;
            u[3] <= 4'd0; v[3] <= 4'd0;

            // Initialize orientation
            from[0] <= 4'd0; to[0] <= 4'd0;
            from[1] <= 4'd0; to[1] <= 4'd0;
            from[2] <= 4'd0; to[2] <= 4'd0;
            from[3] <= 4'd0; to[3] <= 4'd0;

            // Initialize Floyd-Warshall
            k <= 2'd0; i <= 2'd0; j <= 2'd0;
            temp_dist <= 4'd0;

            // Initialize distance matrix
            integer idx1, idx2;
            for (idx1 = 0; idx1 < 4; idx1 = idx1 + 1) begin
                for (idx2 = 0; idx2 < 4; idx2 = idx2 + 1) begin
                    dist[idx1][idx2] <= 4'd0;
                end
            end

            // Initialize strong connectivity
            reachable <= 4'd0;
            strong_connected <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 10'd0;
                if (start) begin
                    next_state <= CHECK_START;
                end else begin
                    next_state <= IDLE;
                end
            end

            CHECK_START: begin
                // Store edges
                u[0] <= edge_0[3:0]; v[0] <= edge_0[7:4];
                u[1] <= edge_1[3:0]; v[1] <= edge_1[7:4];
                u[2] <= edge_2[3:0]; v[2] <= edge_2[7:4];
                u[3] <= edge_3[3:0]; v[3] <= edge_3[7:4];

                // Calculate max orientations
                max_orient <= 1 << m;
                orient_count <= 3'd0;
                next_state <= BUILD_ORIENT;
            end

            BUILD_ORIENT: begin
                // Build current orientation
                integer idx;
                for (idx = 0; idx < 4; idx = idx + 1) begin
                    if (idx < m) begin
                        if (orient_count[idx]) begin
                            from[idx] <= v[idx];
                            to[idx] <= u[idx];
                        end else begin
                            from[idx] <= u[idx];
                            to[idx] <= v[idx];
                        end
                    end else begin
                        from[idx] <= 4'd0;
                        to[idx] <= 4'd0;
                    end
                end
                next_state <= FLOYD_INIT;
            end

            FLOYD_INIT: begin
                // Initialize distance matrix
                integer idx1, idx2;
                for (idx1 = 0; idx1 < 4; idx1 = idx1 + 1) begin
                    for (idx2 = 0; idx2 < 4; idx2 = idx2 + 1) begin
                        if (idx1 == idx2) begin
                            dist[idx1][idx2] <= 4'd1;
                        end else begin
                            dist[idx1][idx2] <= 4'd0;
                        end
                    end
                end

                // Set direct edges
                for (idx1 = 0; idx1 < 4; idx1 = idx1 + 1) begin
                    if (idx1 < m) begin
                        dist[from[idx1]][to[idx1]] <= 4'd1;
                    end
                end

                k <= 2'd0;
                i <= 2'd0;
                j <= 2'd0;
                next_state <= FLOYD_K_LOOP;
            end

            FLOYD_K_LOOP: begin
                if (k == 2'd3) begin
                    next_state <= FLOYD_IJ_LOOP;
                end else begin
                    i <= 2'd0;
                    j <= 2'd0;
                    next_state <= FLOYD_IJ_LOOP;
                end
            end

            FLOYD_IJ_LOOP: begin
                if (i == 2'd3 && j == 2'd3) begin
                    k <= k + 2'd1;
                    next_state <= FLOYD_K_LOOP;
                end else begin
                    if (j == 2'd3) begin
                        i <= i + 2'd1;
                        j <= 2'd0;
                    end else begin
                        j <= j + 2'd1;
                    end

                    // Floyd-Warshall update
                    if (dist[i][k] && dist[k][j]) begin
                        dist[i][j] <= 4'd1;
                    end
                end
            end

            CHECK_STRONG: begin
                // Check strong connectivity
                integer idx1, idx2;
                strong_connected <= 1'b1;
                for (idx1 = 0; idx1 < 4; idx1 = idx1 + 1) begin
                    for (idx2 = 0; idx2 < 4; idx2 = idx2 + 1) begin
                        if (!dist[idx1][idx2]) begin
                            strong_connected <= 1'b0;
                        end
                    end
                end

                if (strong_connected) begin
                    next_state <= OUTPUT;
                end else begin
                    next_state <= NEXT_ORIENT;
                end
            end

            NEXT_ORIENT: begin
                orient_count <= orient_count + 3'd1;
                if (orient_count == max_orient) begin
                    next_state <= OUTPUT;
                end else begin
                    next_state <= BUILD_ORIENT;
                end
            end

            OUTPUT: begin
                if (strong_connected) begin
                    yes_no <= 1'b1;
                    // Output orientation
                    orient_0 <= {from[0], to[0]};
                    orient_1 <= {from[1], to[1]};
                    orient_2 <= {from[2], to[2]};
                    orient_3 <= {from[3], to[3]};
                end else begin
                    yes_no <= 1'b0;
                    orient_0 <= 8'd0;
                    orient_1 <= 8'd0;
                    orient_2 <= 8'd0;
                    orient_3 <= 8'd0;
                end
                next_state <= DONE_STATE;
            end

            DONE_STATE: begin
                done <= 1'b1;
                next_state <= IDLE;
            end

            default: next_state <= IDLE;
        endcase

        // Cycle counter for timeout
        if (cycle_count < MAX_CYCLES) begin
            cycle_count <= cycle_count + 10'd1;
        end else begin
            cycle_count <= 10'd0;
            next_state <= IDLE;
        end
    end

endmodule