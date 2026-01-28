module transport_solver #(
    parameter T = 4,
    parameter N = 8,
    parameter DATA_WIDTH = 32,
    parameter INF = 32'hFFFF_FFFF
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] num_points,
    input wire [DATA_WIDTH-1:0] d_min [0:T-1],
    input wire [DATA_WIDTH-1:0] a [0:T-1],
    input wire [DATA_WIDTH-1:0] d [0:N-2],
    input wire [DATA_WIDTH-1:0] h [0:N-2],
    output reg [DATA_WIDTH-1:0] result,
    output reg result_valid
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOOP_I = 3'd1;
localparam [2:0] LOOP_J = 3'd2;
localparam [2:0] LOOP_T = 3'd3;
localparam [2:0] SEG_LOOP = 3'd4;
localparam [2:0] UPDATE_DP = 3'd5;
localparam [2:0] DONE = 3'd6;

// Registers
reg [2:0] state;
reg [DATA_WIDTH-1:0] dp [0:N-1];
reg [DATA_WIDTH-1:0] i, j, t, k;
reg [DATA_WIDTH-1:0] seg_dist;
reg signed [DATA_WIDTH-1:0] seg_min_h, seg_max_h;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        result_valid <= 1'b0;
        for (integer idx = 0; idx < N; idx = idx + 1) begin
            dp[idx] <= INF;
        end
        i <= 32'd0;
        j <= 32'd0;
        t <= 32'd0;
        k <= 32'd0;
        seg_dist <= 32'd0;
        seg_min_h <= 32'sd2147483647; // Max positive signed
        seg_max_h <= 32'sh80000000;   // Min negative (-2147483648)
    end else begin
        case (state)
            IDLE: begin
                result_valid <= 1'b0;
                if (start) begin
                    dp[0] <= 32'd0;
                    for (integer idx = 1; idx < N; idx = idx + 1) begin
                        dp[idx] <= INF;
                    end
                    i <= 32'd1;
                    state <= LOOP_I;
                end
            end

            LOOP_I: begin
                if (i >= num_points) begin
                    state <= DONE;
                end else begin
                    j <= 32'd0;
                    state <= LOOP_J;
                end
            end

            LOOP_J: begin
                if (j >= i) begin
                    i <= i + 32'd1;
                    state <= LOOP_I;
                end else begin
                    t <= 32'd0;
                    state <= LOOP_T;
                end
            end

            LOOP_T: begin
                if (t >= T) begin
                    j <= j + 32'd1;
                    state <= LOOP_J;
                end else begin
                    k <= j;
                    seg_dist <= 32'd0;
                    seg_min_h <= 32'sd2147483647;
                    seg_max_h <= 32'sh80000000;
                    state <= SEG_LOOP;
                end
            end

            SEG_LOOP: begin
                if (k >= i) begin
                    state <= UPDATE_DP;
                end else begin
                    seg_dist <= seg_dist + d[k];
                    if ($signed(h[k]) < seg_min_h) seg_min_h <= $signed(h[k]);
                    if ($signed(h[k]) > seg_max_h) seg_max_h <= $signed(h[k]);
                    k <= k + 32'd1;
                end
            end

            UPDATE_DP: begin
                if (dp[j] != INF) begin
                    if ((seg_dist >= d_min[t]) && (($signed(seg_max_h) - $signed(seg_min_h)) <= $signed(a[t]))) begin
                        if ((dp[j] + 32'd1) < dp[i]) begin
                            dp[i] <= dp[j] + 32'd1;
                        end
                    end
                end
                t <= t + 32'd1;
                state <= LOOP_T;
            end

            DONE: begin
                if (num_points > 32'd0) begin
                    result <= (dp[num_points-32'd1] == INF) ? 32'hFFFF_FFFF : dp[num_points-32'd1];
                end else begin
                    result <= INF;
                end
                result_valid <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule