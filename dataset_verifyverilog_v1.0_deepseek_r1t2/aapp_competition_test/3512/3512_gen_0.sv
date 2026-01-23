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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP = 3'd2;
    localparam [2:0] FINAL = 3'd3;

    reg [2:0] state;
    reg [4:0] M, l, r;
    reg [RESULT_WIDTH-1:0] dp [1:MAX_N][1:MAX_N];
    reg [RESULT_WIDTH-1:0] INF;
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= {RESULT_WIDTH{1'b0}};
            M <= 5'd0;
            l <= 5'd0;
            r <= 5'd0;
            INF <= {RESULT_WIDTH{1'b1}};
            
            // Initialize dp array
            for (i = 1; i <= MAX_N; i = i + 1) begin
                for (j = 1; j <= MAX_N; j = j + 1) begin
                    dp[i][j] <= {RESULT_WIDTH{1'b1}};
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize dp array to INF
                    for (i = 1; i <= MAX_N; i = i + 1) begin
                        for (j = 1; j <= MAX_N; j = j + 1) begin
                            dp[i][j] <= INF;
                        end
                    end
                    
                    dp[1][1] <= {RESULT_WIDTH{1'b0}};
                    M <= 5'd1;
                    l <= 5'd1;
                    r <= 5'd1;
                    
                    if (N > 5'd1) state <= LOOP;
                    else state <= FINAL;
                end

                LOOP: begin
                    // Process current (M, l, r)
                    if ((l == M || r == M) && dp[l][r] != INF) begin
                        if (dp[l][r] + w[l-1][M] < dp[M+5'd1][r]) begin
                            dp[M+5'd1][r] <= dp[l][r] + w[l-1][M];
                        end
                        
                        if (dp[l][r] + w[r-1][M] < dp[l][M+5'd1]) begin
                            dp[l][M+5'd1] <= dp[l][r] + w[r-1][M];
                        end
                    end
                    
                    // Update counters
                    if (r < N) begin
                        r <= r + 5'd1;
                    end else begin
                        r <= 5'd1;
                        if (l < N) begin
                            l <= l + 5'd1;
                        end else begin
                            l <= 5'd1;
                            if (M < N-5'd1) begin
                                M <= M + 5'd1;
                            end else begin
                                state <= FINAL;
                            end
                        end
                    end
                end

                FINAL: begin
                    // Find minimum result
                    result <= INF;
                    for (i = 1; i <= N; i = i + 1) begin
                        for (j = 1; j <= N; j = j + 1) begin
                            if ((i == N || j == N) && dp[i][j] < result) begin
                                result <= dp[i][j];
                            end
                        end
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule