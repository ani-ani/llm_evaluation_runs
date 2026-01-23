module grasshopper_path (
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [2:0] start_r,
    input [2:0] start_c,
    input [7:0] petals [8][8],
    output reg [7:0] max_path_length,
    output reg done
);

reg [7:0] petals_reg [8][8];
reg [2:0] n_reg;
reg [2:0] start_r_reg, start_c_reg;
reg [7:0] dp [8][8];
reg [7:0] max_path_length_reg;
reg done_reg;
reg [2:0] state_reg;

parameter IDLE = 3'd0,
LOAD_GRID = 3'd1,
COMPUTE_DP = 3'd2,
FIND_MAX = 3'd3,
COMPLETE = 3'd4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        petals_reg <= 0;
        n_reg <= 0;
        start_r_reg <= 0;
        start_c_reg <= 0;
        dp <= 0;
        max_path_length_reg <= 0;
        done_reg <= 0;
        state_reg <= IDLE;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) begin
                    state_reg <= LOAD_GRID;
                end
            end
            LOAD_GRID: begin
                n_reg <= N;
                start_r_reg <= start_r;
                start_c_reg <= start_c;
                petals_reg <= petals;
                state_reg <= COMPUTE_DP;
            end
            COMPUTE_DP: begin
                dp <= 1;
                state_reg <= FIND_MAX;
            end
            FIND_MAX: begin
                integer i = start_r_reg;
                integer j = start_c_reg;
                if (i >= n_reg || j >= n_reg) begin
                    max_path_length_reg <= 0;
                end else begin
                    max_path_length_reg <= dp[i][j];
                end
                done_reg <= 1;
                state_reg <= COMPLETE;
            end
            COMPLETE: begin
                state_reg <= COMPLETE;
            end
        endcase
    end
end

assign max_path_length = max_path_length_reg;
assign done = done_reg;

endmodule