module grid_path_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] din,
    input wire [5:0] addr,
    input wire write,
    input wire [2:0] N,
    output reg [15:0] max_sum,
    output reg [3:0] path_len,
    output reg valid
);
    
    // Internal Memory for Cost Matrix (64 entries x 8-bit)
    reg [7:0] cost_mem [0:63];
    
    // DP Table Registers (8x8 grid, 16-bit sums to handle max ~3800)
    reg [15:0] dp [0:7][0:7];
    
    // State Machine Definition
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] START = 3'd1;
    localparam [2:0] ROW_FILL = 3'd2;
    localparam [2:0] COL_FILL = 3'd3;
    localparam [2:0] FILL = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;
    
    reg [2:0] state;
    reg [2:0] i, j; // Loop counters
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            max_sum <= 16'd0;
            path_len <= 4'd0;
            
            // Initialize cost memory
            integer k;
            for (k = 0; k < 64; k = k + 1) begin
                cost_mem[k] <= 8'd0;
            end
            
            // Initialize DP table
            integer m, n;
            for (m = 0; m < 8; m = m + 1) begin
                for (n = 0; n < 8; n = n + 1) begin
                    dp[m][n] <= 16'd0;
                end
            end
        end else begin
            valid <= 1'b0; // Auto-clear valid
            
            case (state)
                IDLE: begin
                    // Handle synchronous memory loading
                    if (write) begin
                        cost_mem[addr] <= din;
                    end
                    
                    if (start) begin
                        // Initialize counters for computation
                        i <= 3'd0;
                        j <= 3'd0;
                        state <= START;
                    end
                end
                
                START: begin
                    // Initialize top-left cell
                    dp[0][0] <= cost_mem[0];
                    j <= 3'd1;
                    state <= ROW_FILL;
                end
                
                ROW_FILL: begin
                    if (j < N) begin
                        // Fill row 0: dp[0][j] = dp[0][j-1] + cost_mem[j]
                        dp[0][j] <= dp[0][j-1] + cost_mem[j];
                        j <= j + 3'd1;
                    end else begin
                        // Row fill done, move to column fill
                        i <= 3'd1;
                        state <= COL_FILL;
                    end
                end
                
                COL_FILL: begin
                    if (i < N) begin
                        // Fill col 0: dp[i][0] = dp[i-1][0] + cost_mem[i*8]
                        dp[i][0] <= dp[i-1][0] + cost_mem[{i, 3'd0}];
                        i <= i + 3'd1;
                    end else begin
                        // Column fill done, move to inner cells
                        i <= 3'd1;
                        j <= 3'd1;
                        state <= FILL;
                    end
                end
                
                FILL: begin
                    if (i < N) begin
                        if (j < N) begin
                            // Fill dp[i][j] = max(dp[i-1][j], dp[i][j-1]) + cost_mem[i*8+j]
                            if (dp[i-1][j] > dp[i][j-1])
                                dp[i][j] <= dp[i-1][j] + cost_mem[{i, j}];
                            else
                                dp[i][j] <= dp[i][j-1] + cost_mem[{i, j}];
                            j <= j + 3'd1;
                        end else begin
                            // End of row, increment i, reset j
                            j <= 3'd1;
                            i <= i + 3'd1;
                        end
                    end else begin
                        // Calculation complete, go to output
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    max_sum <= dp[N-1][N-1];
                    // Calculate path length: 2*N - 1
                    path_len <= {N, 1'b0} - 4'd1;
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule