module min_path #(
    parameter MAX_N = 8,
    parameter DATA_WIDTH = 12,
    parameter RESULT_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] w [0:MAX_N-1][0:MAX_N-1],
    input wire [4:0] N,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// States
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] LOOP = 3'd2;
localparam [2:0] FINAL = 3'd3;

// Internal registers
reg [2:0] state;
reg [4:0] M, l, r;
reg [RESULT_WIDTH-1:0] dp [1:MAX_N][1:MAX_N];
reg [RESULT_WIDTH-1:0] INF;

// Initialize INF
initial begin
    INF = {RESULT_WIDTH{1'b1}};
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= {RESULT_WIDTH{1'b0}};
        M <= 5'd0;
        l <= 5'd0;
        r <= 5'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT;
                end
            end

            INIT: begin
                // Initialize dp to INF
                integer i, j;
                for (i = 1; i <= MAX_N; i = i + 1) begin
                    for (j = 1; j <= MAX_N; j = j + 1) begin
                        dp[i][j] <= INF;
                    end
                end
                // Set base case
                dp[1][1] <= {RESULT_WIDTH{1'b0}};
                // Initialize counters
                M <= 5'd1;
                l <= 5'd1;
                r <= 5'd1;
                // Proceed to loop if N > 1
                if (N > 5'd1)
                    state <= LOOP;
                else
                    state <= FINAL;
            end

            LOOP: begin
                // Process current (M, l, r)
                // Check condition: max(l,r) == M and dp[l][r] is reachable
                if ((l == M || r == M) && (l <= M && r <= M) && (dp[l][r] != INF)) begin
                    // Compute new costs
                    reg [RESULT_WIDTH-1:0] new_cost_left;
                    reg [RESULT_WIDTH-1:0] new_cost_right;
                    // Note: w indices are 0-based, cities are 1-based
                    // w[l-1][M] connects city l to city M+1
                    // w[r-1][M] connects city r to city M+1
                    new_cost_left = dp[l][r] + w[l-1][M];
                    new_cost_right = dp[l][r] + w[r-1][M];

                    // Update dp for new city M+1
                    if (new_cost_left < dp[M+1][r])
                        dp[M+1][r] <= new_cost_left;
                    if (new_cost_right < dp[l][M+1])
                        dp[l][M+1] <= new_cost_right;
                end

                // Increment counters
                if (r < N) begin
                    r <= r + 5'd1;
                end else begin
                    r <= 5'd1;
                    if (l < N) begin
                        l <= l + 5'd1;
                    end else begin
                        l <= 5'd1;
                        if (M < N - 5'd1) begin
                            M <= M + 5'd1;
                        end else begin
                            state <= FINAL;
                        end
                    end
                end
            end

            FINAL: begin
                // Compute minimum over dp[i][j] where max(i,j) == N
                integer i, j;
                reg [RESULT_WIDTH-1:0] min_val;
                min_val = INF;
                for (i = 1; i <= MAX_N; i = i + 1) begin
                    for (j = 1; j <= MAX_N; j = j + 1) begin
                        if (i <= N && j <= N && (i == N || j == N)) begin
                            if (dp[i][j] < min_val) begin
                                min_val = dp[i][j];
                            end
                        end
                    end
                end
                result <= min_val;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule