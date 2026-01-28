module FibonacciTour(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [15:0] heights [0:15],
    input [0:255] adj,
    output reg [4:0] max_len,
    output reg done
);

    // Pre-computed Fibonacci numbers (16-bit)
    localparam [15:0] fib [0:15] = '{16'd1, 16'd1, 16'd2, 16'd3, 16'd5, 16'd8, 16'd13, 16'd21, 16'd34, 16'd55, 16'd89, 16'd144, 16'd233, 16'd377, 16'd610, 16'd987};

    // DP table: dp[k][i] = length of longest path starting at node i with Fibonacci index k
    reg [3:0] dp [0:15][0:15];
    reg [3:0] current_max;

    // State machine
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    reg [1:0] state;

    // Counters
    reg [3:0] k;
    reg [3:0] i;
    reg [3:0] j;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd499;

    // Helper signals
    reg [3:0] n;
    reg [3:0] temp_len;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_len <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            k <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            n <= 4'd0;
            current_max <= 4'd0;

            // Initialize DP table
            integer x, y;
            for (x = 0; x < 16; x = x + 1) begin
                for (y = 0; y < 16; y = y + 1) begin
                    dp[x][y] <= 4'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                        n <= num_nodes;
                    end
                end

                INIT: begin
                    // Initialize DP table for starting nodes
                    for (i = 0; i < n; i = i + 1) begin
                        for (k = 0; k < 16; k = k + 1) begin
                            if (heights[i] == fib[k]) begin
                                dp[k][i] <= 4'd1;
                            end else begin
                                dp[k][i] <= 4'd0;
                            end
                        end
                    end
                    k <= 4'd14;  // Start from highest k
                    i <= 4'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if we've processed all k and i
                    if (k == 4'd0 && i == n) begin
                        state <= FINISH;
                    end else begin
                        // Process current k and i
                        if (dp[k][i] > 4'd0) begin
                            // Check all neighbors j
                            for (j = 0; j < n; j = j + 1) begin
                                if (i != j && adj[i * 16 + j] && heights[j] == fib[k + 1]) begin
                                    temp_len <= dp[k][i] + 4'd1;
                                    if (temp_len > dp[k + 1][j]) begin
                                        dp[k + 1][j] <= temp_len;
                                    end
                                end
                            end
                        end

                        // Move to next i or k
                        if (i == n - 1) begin
                            i <= 4'd0;
                            k <= k - 4'd1;
                        end else begin
                            i <= i + 4'd1;
                        end
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Find maximum length
                    current_max <= 4'd0;
                    for (k = 0; k < 16; k = k + 1) begin
                        for (i = 0; i < n; i = i + 1) begin
                            if (dp[k][i] > current_max) begin
                                current_max <= dp[k][i];
                            end
                        end
                    end
                    max_len <= current_max;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule