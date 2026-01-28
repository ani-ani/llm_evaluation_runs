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
localparam [2:0] IDLE     = 3'd0;
localparam [2:0] LOOP_I   = 3'd1;
localparam [2:0] LOOP_J   = 3'd2;
localparam [2:0] LOOP_T   = 3'd3;
localparam [2:0] SEG_LOOP = 3'd4;
localparam [2:0] UPDATE_DP = 3'd5;
localparam [2:0] DONE     = 3'd6;

// Registers
reg [2:0] state;
reg [DATA_WIDTH-1:0] dp [0:N-1];
reg [DATA_WIDTH-1:0] i_reg, j_reg, t_reg, k_reg;
reg [DATA_WIDTH-1:0] seg_dist;
reg signed [DATA_WIDTH-1:0] seg_min_h, seg_max_h;
reg [DATA_WIDTH-1:0] dp_j_buffer;

// Variables for for-loops
integer idx_loop;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        result_valid <= 1'b0;
        for (idx_loop = 0; idx_loop < N; idx_loop = idx_loop + 1) begin
            dp[idx_loop] <= INF;
        end
        i_reg <= 32'd0;
        j_reg <= 32'd0;
        t_reg <= 32'd0;
        k_reg <= 32'd0;
        seg_dist <= 32'd0;
        seg_min_h <= 32'sh7FFF_FFFF;
        seg_max_h <= 32'sh8000_0000;
        dp_j_buffer <= INF;
    end else begin
        case (state)
            IDLE: begin
                result_valid <= 1'b0;
                if (start) begin
                    // Initialize DP array
                    dp[0] <= 32'd0;
                    for (idx_loop = 1; idx_loop < N; idx_loop = idx_loop + 1) begin
                        dp[idx_loop] <= INF;
                    end
                    i_reg <= 32'd1;
                    state <= LOOP_I;
                end
            end

            LOOP_I: begin
                if (i_reg >= num_points) begin
                    state <= DONE;
                end else begin
                    j_reg <= 32'd0;
                    state <= LOOP_J;
                end
            end

            LOOP_J: begin
                if (j_reg >= i_reg) begin
                    i_reg <= i_reg + 32'd1;
                    state <= LOOP_I;
                end else begin
                    t_reg <= 32'd0;
                    state <= LOOP_T;
                end
            end

            LOOP_T: begin
                if (t_reg >= T) begin
                    j_reg <= j_reg + 32'd1;
                    state <= LOOP_J;
                end else begin
                    k_reg <= j_reg;
                    seg_dist <= 32'd0;
                    seg_min_h <= 32'sh7FFF_FFFF;
                    seg_max_h <= 32'sh8000_0000;
                    state <= SEG_LOOP;
                end
            end

            SEG_LOOP: begin
                if (k_reg >= i_reg) begin
                    state <= UPDATE_DP;
                end else begin
                    seg_dist <= seg_dist + d[k_reg];
                    if ($signed(h[k_reg]) < seg_min_h) begin
                        seg_min_h <= $signed(h[k_reg]);
                    end
                    if ($signed(h[k_reg]) > seg_max_h) begin
                        seg_max_h <= $signed(h[k_reg]);
                    end
                    k_reg <= k_reg + 32'd1;
                    state <= SEG_LOOP;
                end
            end

            UPDATE_DP: begin
                dp_j_buffer <= dp[j_reg];
                if (dp[j_reg] != INF) begin
                    if (seg_dist >= d_min[t_reg] && ((seg_max_h - seg_min_h) <= $signed(a[t_reg]))) begin
                        if (dp[j_reg] + 32'd1 < dp[i_reg]) begin
                            dp[i_reg] <= dp[j_reg] + 32'd1;
                        end
                    end
                end
                t_reg <= t_reg + 32'd1;
                state <= LOOP_T;
            end

            DONE: begin
                if (num_points > 32'd0) begin
                    result <= dp[num_points - 32'd1];
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