module graph_orientation_4bit(
    input clk,
    input rst_n,
    input start,
    input [2:0] m,
    input [7:0] edges [0:3],
    output reg yes_no,
    output reg [7:0] orient [0:3],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CHECK_START   = 4'd1;
    localparam [3:0] BUILD_ORIENT  = 4'd2;
    localparam [3:0] FLOYD_INIT    = 4'd3;
    localparam [3:0] FLOYD_K_LOOP  = 4'd4;
    localparam [3:0] FLOYD_IJ_LOOP = 4'd5;
    localparam [3:0] CHECK_STRONG  = 4'd6;
    localparam [3:0] NEXT_ORIENT   = 4'd7;
    localparam [3:0] OUTPUT        = 4'd8;
    localparam [3:0] DONE          = 4'd9;
    localparam [3:0] NOT_POSSIBLE  = 4'd10;

    reg [3:0] state, next_state;
    reg [2:0] orient_counter;
    reg [2:0] orient_limit;
    reg [1:0] edge_idx;
    reg [1:0] k, i, j;
    reg [1:0] node_i, node_j;
    reg found_strong;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Distance matrix (4x4)
    reg [1:0] dist [0:3][0:3];
    reg [1:0] dist_temp;

    // Temporary orientation bits
    reg [3:0] temp_from, temp_to;
    reg [7:0] temp_orient;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            yes_no <= 1'b0;
            orient[0] <= 8'd0;
            orient[1] <= 8'd0;
            orient[2] <= 8'd0;
            orient[3] <= 8'd0;
            done <= 1'b0;
            orient_counter <= 3'd0;
            orient_limit <= 3'd0;
            edge_idx <= 2'd0;
            k <= 2'd0;
            i <= 2'd0;
            j <= 2'd0;
            node_i <= 2'd0;
            node_j <= 2'd0;
            found_strong <= 1'b0;
            cycle_count <= 8'd0;
            temp_from <= 4'd0;
            temp_to <= 4'd0;
            temp_orient <= 8'd0;
            dist_temp <= 2'd0;
            dist[0][0] <= 2'd0; dist[0][1] <= 2'd0; dist[0][2] <= 2'd0; dist[0][3] <= 2'd0;
            dist[1][0] <= 2'd0; dist[1][1] <= 2'd0; dist[1][2] <= 2'd0; dist[1][3] <= 2'd0;
            dist[2][0] <= 2'd0; dist[2][1] <= 2'd0; dist[2][2] <= 2'd0; dist[2][3] <= 2'd0;
            dist[3][0] <= 2'd0; dist[3][1] <= 2'd0; dist[3][2] <= 2'd0; dist[3][3] <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK_START;
                    end
                end

                CHECK_START: begin
                    // Convert m to limit (2^m)
                    case (m)
                        3'd0: orient_limit <= 3'd1;
                        3'd1: orient_limit <= 3'd2;
                        3'd2: orient_limit <= 3'd4;
                        3'd3: orient_limit <= 3'd8;
                        default: orient_limit <= 3'd8;
                    endcase
                    orient_counter <= 3'd0;
                    found_strong <= 1'b0;
                    state <= BUILD_ORIENT;
                end

                BUILD_ORIENT: begin
                    // Build orientation for current orient_counter
                    edge_idx <= 2'd0;
                    state <= FLOYD_INIT;
                end

                FLOYD_INIT: begin
                    // Initialize distance matrix for this orientation
                    if (edge_idx < m) begin
                        // Check orientation bit
                        if (orient_counter[edge_idx]) begin
                            temp_from <= edges[edge_idx][3:0];
                            temp_to <= edges[edge_idx][7:4];
                        end else begin
                            temp_from <= edges[edge_idx][7:4];
                            temp_to <= edges[edge_idx][3:0];
                        end
                        edge_idx <= edge_idx + 2'd1;
                        state <= FLOYD_INIT;
                    end else begin
                        edge_idx <= 2'd0;
                        k <= 2'd0;
                        i <= 2'd0;
                        j <= 2'd0;
                        state <= FLOYD_K_LOOP;
                    end
                    // Set initial distance
                    if (edge_idx < m) begin
                        dist[temp_from][temp_to] <= 2'd1;
                    end
                    // Also set self distance to 1 for connectivity check
                    for (int idx = 0; idx < 4; idx = idx + 1) begin
                        dist[idx][idx] <= 2'd1;
                    end
                end

                FLOYD_K_LOOP: begin
                    if (k < 4) begin
                        i <= 2'd0;
                        state <= FLOYD_IJ_LOOP;
                    end else begin
                        state <= CHECK_STRONG;
                    end
                end

                FLOYD_IJ_LOOP: begin
                    if (i < 4) begin
                        j <= 2'd0;
                        // Loop through j
                        if (j < 4) begin
                            // Floyd-Warshall update
                            if ((dist[i][k] != 2'd0) && (dist[k][j] != 2'd0)) begin
                                if ((dist[i][k] + dist[k][j]) < dist[i][j]) begin
                                    dist[i][j] <= dist[i][k] + dist[k][j];
                                end
                            end
                            j <= j + 2'd1;
                            state <= FLOYD_IJ_LOOP;
                        end else begin
                            i <= i + 2'd1;
                            state <= FLOYD_IJ_LOOP;
                        end
                    end else begin
                        k <= k + 2'd1;
                        state <= FLOYD_K_LOOP;
                    end
                end

                CHECK_STRONG: begin
                    // Check if all dist[i][j] > 0
                    if (i < 4) begin
                        if (j < 4) begin
                            if (dist[i][j] == 2'd0) begin
                                found_strong <= 1'b0;
                                state <= NEXT_ORIENT;
                            end else begin
                                j <= j + 2'd1;
                                state <= CHECK_STRONG;
                            end
                        end else begin
                            i <= i + 2'd1;
                            j <= 2'd0;
                            state <= CHECK_STRONG;
                        end
                    end else begin
                        found_strong <= 1'b1;
                        state <= OUTPUT;
                    end
                end

                NEXT_ORIENT: begin
                    orient_counter <= orient_counter + 3'd1;
                    if (orient_counter < (orient_limit - 3'd1)) begin
                        state <= BUILD_ORIENT;
                    end else begin
                        state <= NOT_POSSIBLE;
                    end
                end

                OUTPUT: begin
                    yes_no <= 1'b1;
                    // Output the orientation that worked
                    // Recreate orientation from orient_counter
                    for (int e = 0; e < 4; e = e + 1) begin
                        if (e < m) begin
                            if (orient_counter[e]) begin
                                orient[e] <= {edges[e][3:0], edges[e][7:4]};
                            end else begin
                                orient[e] <= {edges[e][7:4], edges[e][3:0]};
                            end
                        end else begin
                            orient[e] <= 8'd0;
                        end
                    end
                    state <= DONE;
                end

                NOT_POSSIBLE: begin
                    yes_no <= 1'b0;
                    for (int e = 0; e < 4; e = e + 1) begin
                        orient[e] <= 8'd0;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= NOT_POSSIBLE;
            end
        end
    end

endmodule