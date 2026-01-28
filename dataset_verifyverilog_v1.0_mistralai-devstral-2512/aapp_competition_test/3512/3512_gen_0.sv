module TSP_Constrained(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N_in,
    input wire [9:0] data_in,
    input wire [3:0] row_in,
    input wire [3:0] col_in,
    input wire write_en,
    output reg [20:0] min_cost,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_N = 3'd1;
    localparam [2:0] READ_MATRIX = 3'd2;
    localparam [2:0] INIT_DP = 3'd3;
    localparam [2:0] COMPUTE_DP = 3'd4;
    localparam [2:0] FINALIZE = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Registers
    reg [2:0] state;
    reg [3:0] N;
    reg [9:0] dist [0:14][0:14];
    reg [20:0] dp_prev [0:14];
    reg [20:0] dp_curr [0:14];
    reg [3:0] i;
    reg [3:0] m;
    reg [3:0] k;
    reg [20:0] temp_min;
    reg [20:0] temp_val;
    reg [3:0] row;
    reg [3:0] col;
    reg [3:0] write_count;
    reg [3:0] total_writes;

    // Initialize all registers in reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            N <= 4'd0;
            for (row = 0; row < 15; row = row + 1) begin
                for (col = 0; col < 15; col = col + 1) begin
                    dist[row][col] <= 10'd0;
                end
            end
            for (m = 0; m < 15; m = m + 1) begin
                dp_prev[m] <= 21'd0;
                dp_curr[m] <= 21'd0;
            end
            i <= 4'd0;
            m <= 4'd0;
            k <= 4'd0;
            temp_min <= 21'd0;
            temp_val <= 21'd0;
            row <= 4'd0;
            col <= 4'd0;
            write_count <= 4'd0;
            total_writes <= 4'd0;
            min_cost <= 21'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= READ_N;
                    end
                end

                READ_N: begin
                    N <= N_in;
                    total_writes <= N * N;
                    write_count <= 4'd0;
                    state <= READ_MATRIX;
                end

                READ_MATRIX: begin
                    if (write_en) begin
                        dist[row_in][col_in] <= data_in;
                        write_count <= write_count + 4'd1;
                        if (write_count == total_writes) begin
                            state <= INIT_DP;
                        end
                    end
                end

                INIT_DP: begin
                    // Initialize dp_prev for i=2
                    dp_prev[0] <= dist[0][1]; // dp[2][1] = dist(1,2)
                    for (m = 1; m < 15; m = m + 1) begin
                        dp_prev[m] <= 21'd0;
                    end
                    i <= 4'd2; // Start from i=3
                    state <= COMPUTE_DP;
                end

                COMPUTE_DP: begin
                    // Compute dp_curr for current i
                    // First, copy dp_prev to dp_curr for m < i-1
                    for (m = 0; m < i-1; m = m + 1) begin
                        dp_curr[m] <= dp_prev[m] + dist[i-1][i-2]; // dist(i, i-1)
                    end

                    // Compute dp_curr[i-2] = min over m of (dp_prev[m] + dist(i, m+1))
                    temp_min <= 21'd0;
                    for (m = 0; m < i-2; m = m + 1) begin
                        temp_val <= dp_prev[m] + dist[i-1][m]; // dist(i, m+1)
                        if (m == 0 || temp_val < temp_min) begin
                            temp_min <= temp_val;
                        end
                    end
                    dp_curr[i-2] <= temp_min;

                    // Copy dp_curr to dp_prev for next iteration
                    for (m = 0; m < 15; m = m + 1) begin
                        dp_prev[m] <= dp_curr[m];
                    end

                    // Increment i
                    i <= i + 4'd1;
                    if (i == N) begin
                        state <= FINALIZE;
                    end
                end

                FINALIZE: begin
                    // Find min over k of dp_prev[k] for k=0 to N-2
                    temp_min <= 21'd0;
                    for (k = 0; k < N-1; k = k + 1) begin
                        if (k == 0 || dp_prev[k] < temp_min) begin
                            temp_min <= dp_prev[k];
                        end
                    end
                    min_cost <= temp_min;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule