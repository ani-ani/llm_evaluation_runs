module permutation_counter(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [7:0] C,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam MAX_N = 4'd10;
    localparam MAX_C = 8'd256;

    // States
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] COMPUTE_N = 4'd2;
    localparam [3:0] COMPUTE_C = 4'd3;
    localparam [3:0] UPDATE = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    // Internal registers
    reg [3:0] state;
    reg [3:0] current_n;
    reg [7:0] current_c;
    reg [7:0] k;
    reg [31:0] sum;
    reg [31:0] dp [0:10][0:256];
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Clamp inputs
    wire [3:0] clamped_N = (N > MAX_N) ? MAX_N : N;
    wire [7:0] clamped_C = (C > MAX_C) ? MAX_C : C;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 16'd0;
            current_n <= 4'd0;
            current_c <= 8'd0;
            k <= 8'd0;
            sum <= 32'd0;
            // Initialize DP table
            integer i, j;
            for (i = 0; i <= 10; i = i + 1) begin
                for (j = 0; j <= 256; j = j + 1) begin
                    dp[i][j] <= 32'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= INIT;
                        busy <= 1'b1;
                    end
                end

                INIT: begin
                    // Initialize DP table
                    dp[0][0] <= 32'd1;
                    integer i, j;
                    for (i = 0; i <= 10; i = i + 1) begin
                        for (j = 0; j <= 256; j = j + 1) begin
                            if (i == 0 && j == 0) begin
                                dp[i][j] <= 32'd1;
                            end else begin
                                dp[i][j] <= 32'd0;
                            end
                        end
                    end
                    current_n <= 4'd1;
                    current_c <= 8'd0;
                    state <= COMPUTE_N;
                end

                COMPUTE_N: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (current_n > clamped_N) begin
                        state <= DONE_STATE;
                    end else begin
                        current_c <= 8'd0;
                        state <= COMPUTE_C;
                    end
                end

                COMPUTE_C: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (current_c > clamped_C) begin
                        current_n <= current_n + 4'd1;
                        state <= COMPUTE_N;
                    end else begin
                        k <= 8'd0;
                        sum <= 32'd0;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (k > current_c && k > current_n - 4'd1) begin
                        dp[current_n][current_c] <= sum;
                        current_c <= current_c + 8'd1;
                        state <= COMPUTE_C;
                    end else begin
                        if (k <= current_c && k <= current_n - 4'd1) begin
                            sum <= (sum + dp[current_n - 4'd1][current_c - k]) % MOD;
                        end
                        k <= k + 8'd1;
                    end
                end

                DONE_STATE: begin
                    result <= dp[clamped_N][clamped_C];
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule