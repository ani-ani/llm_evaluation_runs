module dj_polygon_gigs (
    input clk,
    input rst_n,
    input start,
    input [4:0] total_gigs,
    input [4:0] total_venues,
    input [31:0] dist_matrix [0:63],
    input [2:0] gig_venue [0:15],
    input [31:0] gig_start [0:15],
    input [31:0] gig_end [0:15],
    input [15:0] gig_money [0:15],
    output reg [15:0] max_earnings,
    output reg done
);

reg [15:0] max_earnings;
reg done;
reg [2:0] state;
reg [4:0] reg_total_gigs;
reg [15:0] dp [0:15];

localparam IDLE = 0;
localparam SORT = 1;
localparam DP_INIT = 2;
localparam DP_OUTER = 3;
localparam DONE = 6;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        max_earnings <= 0;
        done <= 0;
        reg_total_gigs <= 0;
        dp <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= SORT;
            end
            SORT: begin
                state <= DP_INIT;
            end
            DP_INIT: begin
                dp <= 0;
                state <= DP_OUTER;
            end
            DP_OUTER: begin
                max_earnings = 0;
                if (reg_total_gigs >0) begin
                    if (dp[0] > max_earnings) max_earnings = dp[0];
                end
                if (reg_total_gigs >1) begin
                    if (dp[1] > max_earnings) max_earnings = dp[1];
                end
                if (reg_total_gigs >2) begin
                    if (dp[2] > max_earnings) max_earnings = dp[2];
                end
                if (reg_total_gigs >3) begin
                    if (dp[3] > max_earnings) max_earnings = dp[3];
                end
                if (reg_total_gigs >4) begin
                    if (dp[4] > max_earnings) max_earnings = dp[4];
                end
                if (reg_total_gigs >5) begin
                    if (dp[5] > max_earnings) max_earnings = dp[5];
                end
                if (reg_total_gigs >6) begin
                    if (dp[6] > max_earnings) max_earnings = dp[6];
                end
                if (reg_total_gigs >7) begin
                    if (dp[7] > max_earnings) max_earnings = dp[7];
                end
                if (reg_total_gigs >8) begin
                    if (dp[8] > max_earnings) max_earnings = dp[8];
                end
                if (reg_total_gigs >9) begin
                    if (dp[9] > max_earnings) max_earnings = dp[9];
                end
                if (reg_total_gigs >10) begin
                    if (dp[10] > max_earnings) max_earnings = dp[10];
                end
                if (reg_total_gigs >11) begin
                    if (dp[11] > max_earnings) max_earnings = dp[11];
                end
                if (reg_total_gigs >12) begin
                    if (dp[12] > max_earnings) max_earnings = dp[12];
                end
                if (reg_total_gigs >13) begin
                    if (dp[13] > max_earnings) max_earnings = dp[13];
                end
                if (reg_total_gigs >14) begin
                    if (dp[14] > max_earnings) max_earnings = dp[14];
                end
                if (reg_total_gigs >15) begin
                    if (dp[15] > max_earnings) max_earnings = dp[15];
                end
                done <= 1;
                state <= DONE;
            end
            DONE: begin
                // Stay in done state
            end
            default: state <= IDLE;
        endcase
    end
endmodule