module flight_review_planner (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] config_addr,
    input wire [23:0] config_data,
    input wire config_valid,
    output reg [23:0] result,
    output reg done
);

    // Constants
    localparam N = 8; // Number of nodes (0 to 7)
    localparam INF = 24'hFFFFFF;
    localparam MAX_MASK = (1 << N) - 1;

    // State machine states
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] FLOYD_K = 4'd2;
    localparam [3:0] FLOYD_I = 4'd3;
    localparam [3:0] FLOYD_J = 4'd4;
    localparam [3:0] DP_INIT = 4'd5;
    localparam [3:0] DP_MASK_LOOP = 4'd6;
    localparam [3:0] DP_NODE_LOOP = 4'd7;
    localparam [3:0] DP_EXTEND = 4'd8;
    localparam [3:0] FINISH = 4'd9;
    localparam [3:0] DONE_STATE = 4'd10;

    // Registers
    reg [3:0] state;
    reg [2:0] k, i, j; // Floyd-Warshall loop counters
    reg [7:0] mask; // DP mask
    reg [2:0] u, v; // Node indices
    reg [23:0] current_cost;
    reg [23:0] new_cost;
    reg [23:0] min_result;
    reg [7:0] required_mask;
    reg [23:0] dist [0:N-1][0:N-1];
    reg [23:0] dp [0:MAX_MASK][0:N-1];

    // Counters for safety
    reg [16:0] cycle_count;
    localparam [16:0] MAX_CYCLES = 17'd100000;

    // Initialize arrays
    integer idx1, idx2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            k <= 0;
            i <= 0;
            j <= 0;
            mask <= 0;
            u <= 0;
            v <= 0;
            current_cost <= 0;
            new_cost <= 0;
            min_result <= INF;
            required_mask <= 0;
            result <= 0;
            done <= 0;
            cycle_count <= 0;

            // Initialize dist matrix
            for (idx1 = 0; idx1 < N; idx1 = idx1 + 1) begin
                for (idx2 = 0; idx2 < N; idx2 = idx2 + 1) begin
                    dist[idx1][idx2] <= INF;
                end
            end

            // Initialize dp array
            for (idx1 = 0; idx1 <= MAX_MASK; idx1 = idx1 + 1) begin
                for (idx2 = 0; idx2 < N; idx2 = idx2 + 1) begin
                    dp[idx1][idx2] <= INF;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    if (config_valid) begin
                        // Load configuration data
                        if (config_addr < 8) begin
                            // Loading required_mask
                            required_mask <= config_data[7:0];
                        end else begin
                            // Loading dist matrix
                            idx1 = (config_addr - 8) / 8;
                            idx2 = (config_addr - 8) % 8;
                            if (idx1 < N && idx2 < N) begin
                                dist[idx1][idx2] <= config_data;
                            end
                        end
                        state <= FLOYD_K;
                    end
                end

                FLOYD_K: begin
                    if (k == N) begin
                        state <= DP_INIT;
                        k <= 0;
                    end else begin
                        state <= FLOYD_I;
                    i <= 0;
                    j <= 0;
                    k <= k + 1;
                    cycle_count <= cycle_count + 1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end
                end

                FLOYD_I: begin
                    if (i == N) begin
                        state <= FLOYD_K;
                        k <= k + 1;
                    end else begin
                        state <= FLOYD_J;
                        j <= 0;
                        i <= i + 1;
                        cycle_count <= cycle_count + 1;
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= IDLE;
                        end
                    end
                end

                FLOYD_J: begin
                    if (j == N) begin
                        state <= FLOYD_I;
                        i <= i + 1;
                    end else begin
                        // Floyd-Warshall update
                        if (dist[i][k] != INF && dist[k][j] != INF) begin
                            if (dist[i][j] > dist[i][k] + dist[k][j]) begin
                                dist[i][j] <= dist[i][k] + dist[k][j];
                            end
                        end
                        j <= j + 1;
                        cycle_count <= cycle_count + 1;
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= IDLE;
                        end
                    end
                end

                DP_INIT: begin
                    // Initialize DP state
                    dp[1][0] <= 0;
                    mask <= 1;
                    u <= 0;
                    state <= DP_MASK_LOOP;
                    cycle_count <= cycle_count + 1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                DP_MASK_LOOP: begin
                    if (mask == MAX_MASK) begin
                        state <= FINISH;
                    end else begin
                        u <= 0;
                        state <= DP_NODE_LOOP;
                        cycle_count <= cycle_count + 1;
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= IDLE;
                        end
                    end
                end

                DP_NODE_LOOP: begin
                    if (u == N) begin
                        mask <= mask + 1;
                        state <= DP_MASK_LOOP;
                        cycle_count <= cycle_count + 1;
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= IDLE;
                        end
                    end else begin
                        current_cost <= dp[mask][u];
                        if (current_cost != INF) begin
                            v <= 0;
                            state <= DP_EXTEND;
                        end else begin
                            u <= u + 1;
                            cycle_count <= cycle_count + 1;
                            if (cycle_count >= MAX_CYCLES) begin
                                state <= IDLE;
                            end
                        end
                    end
                end

                DP_EXTEND: begin
                    if (v == N) begin
                        u <= u + 1;
                        state <= DP_NODE_LOOP;
                        cycle_count <= cycle_count + 1;
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= IDLE;
                        end
                    end else begin
                        if (!(mask & (1 << v)) && dist[u][v] != INF) begin
                            new_mask = mask | (1 << v);
                            new_cost = current_cost + dist[u][v];
                            if (dp[new_mask][v] > new_cost) begin
                                dp[new_mask][v] <= new_cost;
                            end
                        end
                        v <= v + 1;
                        cycle_count <= cycle_count + 1;
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= IDLE;
                        end
                    end
                end

                FINISH: begin
                    min_result <= INF;
                    for (u = 0; u < N; u = u + 1) begin
                        if ((mask & (1 << u)) && (dist[u][0] != INF)) begin
                            current_cost = dp[MAX_MASK][u] + dist[u][0];
                            if (min_result > current_cost) begin
                                min_result = current_cost;
                            end
                        end
                    end
                    result <= min_result;
                    done <= 1;
                    state <= DONE_STATE;
                    cycle_count <= cycle_count + 1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                DONE_STATE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                    cycle_count <= cycle_count + 1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    done <= 0;
                end
            endcase
        end
    end

endmodule