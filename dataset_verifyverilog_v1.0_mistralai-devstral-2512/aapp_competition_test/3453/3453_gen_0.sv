module GraphDangerCalculator(
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [23:0] edges [0:15],
    input [15:0] edge_valid,
    output reg [15:0] result [0:7],
    output reg done
);

    // Constants
    localparam [15:0] INF = 16'd65535;
    localparam [31:0] MOD = 32'd1000000007;
    localparam [15:0] MOD_16 = 16'd1000000007;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] SUM = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Distance matrix (8x8 nodes, 16-bit distances)
    reg [15:0] dist [0:7];
    reg [15:0] dist_next [0:7];

    // Loop counters
    reg [2:0] k, i, j;
    reg [2:0] sum_i;

    // Accumulator for sum
    reg [31:0] sum_accum;

    // Initialize all registers
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            k <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            sum_i <= 3'd0;
            sum_accum <= 32'd0;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                dist[idx] <= INF;
                dist_next[idx] <= INF;
                result[idx] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Initialize distance matrix
                    for (idx = 0; idx < 8; idx = idx + 1) begin
                        dist[idx] <= INF;
                        dist_next[idx] <= INF;
                    end
                    // Set diagonal to 0
                    for (idx = 0; idx < 8; idx = idx + 1) begin
                        dist[idx][idx] <= 16'd0;
                        dist_next[idx][idx] <= 16'd0;
                    end
                    // Load edges
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        if (edge_valid[idx]) begin
                            reg [3:0] src = edges[idx][3:0];
                            reg [3:0] dst = edges[idx][11:8];
                            reg [7:0] len = edges[idx][19:12];
                            if (src < node_count && dst < node_count) begin
                                dist[src][dst] <= len;
                                dist_next[src][dst] <= len;
                            end
                        end
                    end
                    state <= COMPUTE;
                    k <= 3'd0;
                    i <= 3'd0;
                    j <= 3'd0;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Floyd-Warshall algorithm
                    if (j == 7) begin
                        if (i == 7) begin
                            if (k == 7) begin
                                state <= SUM;
                                sum_i <= 3'd0;
                                sum_accum <= 32'd0;
                            end else begin
                                k <= k + 3'd1;
                                i <= 3'd0;
                                j <= 3'd0;
                                // Copy dist_next to dist
                                for (idx = 0; idx < 8; idx = idx + 1) begin
                                    dist[idx] <= dist_next[idx];
                                end
                            end
                        end else begin
                            i <= i + 3'd1;
                            j <= 3'd0;
                        end
                    end else begin
                        j <= j + 3'd1;
                    end

                    // Compute dist_next[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])
                    if (k < node_count && i < node_count && j < node_count) begin
                        reg [15:0] via_k = dist[i][k] + dist[k][j];
                        if (via_k < dist[i][j]) begin
                            dist_next[i][j] <= via_k;
                        end else begin
                            dist_next[i][j] <= dist[i][j];
                        end
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Sum distances for each node
                    if (sum_i == 7) begin
                        state <= FINISH;
                    end else begin
                        if (j == 7) begin
                            // Store result and reset for next node
                            result[sum_i] <= sum_accum[15:0];
                            sum_i <= sum_i + 3'd1;
                            sum_accum <= 32'd0;
                            j <= 3'd0;
                        end else begin
                            j <= j + 3'd1;
                            if (sum_i < node_count && j < node_count) begin
                                sum_accum <= sum_accum + dist[sum_i][j];
                                // Modulo operation
                                if (sum_accum >= MOD) begin
                                    sum_accum <= sum_accum - MOD;
                                end
                            end
                        end
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule