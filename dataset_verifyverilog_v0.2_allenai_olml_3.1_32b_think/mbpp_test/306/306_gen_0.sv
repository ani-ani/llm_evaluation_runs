module max_sum_increasing_subseq (
input clk,
 input rst_n,
 input start,
 input [2:0] i_index,
 input [2:0] k_index,
 input [15:0] a [0:7],
 output reg [15:0] result,
 output reg done
);

reg [31:0] dp [7][8];
reg [2:0] current_i;
reg [2:0] current_j;
reg [2:0] init_counter;
reg [2:0] target_i_reg;
reg [2:0] target_j_reg;
reg [31:0] a0_reg;
reg [3:0] state;
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 0;
        target_i_reg <= 0;
        target_j_reg <= 0;
        a0_reg <= 0;
        init_counter <= 0;
        current_i <= 0;
        current_j <= 0;
        done_reg <= 0;
        result <= 0;
    end else begin
        case(state)
            0: begin
                if (start) begin
                    target_i_reg <= i_index;
                    target_j_reg <= k_index;
                    a0_reg <= {16'd0, a[0]};
                    state <= 1;
                    init_counter <= 0;
                end
                done_reg <= 0;
                result <= 0;
            end
            1: begin
                if (init_counter < 8) begin
                    reg [31:0] a_j = {16'd0, a[init_counter]};
                    if (a_j > a0_reg) begin
                        dp[0][init_counter] <= a0_reg + a_j;
                    end else begin
                        dp[0][init_counter] <= a_j;
                    end
                    init_counter <= init_counter + 1;
                end else begin
                    state <= 2;
                    current_i <= 1;
                    current_j <= 0;
                end
                done_reg <= 0;
                result <= 0;
            end
            2: begin
                if (current_i > target_i_reg) begin
                    state <= 3;
                end else begin
                    if (current_j < 8) begin
                        reg [31:0] a_i_val = {16'd0, a[current_i]};
                        reg [31:0] a_j_val = {16'd0, a[current_j]};
                        if (a_j_val > a_i_val && current_j > current_i) begin
                            reg [31:0] candidate1 = dp[current_i-1][current_i] + a_j_val;
                            reg [31:0] candidate2 = dp[current_i-1][current_j];
                            if (candidate1 > candidate2) begin
                                dp[current_i][current_j] <= candidate1;
                            end else begin
                                dp[current_i][current_j] <= candidate2;
                            end
                        end else begin
                            dp[current_i][current_j] <= dp[current_i-1][current_j];
                        end
                        current_j <= current_j + 1;
                    end else begin
                        current_j <= 0;
                        current_i <= current_i + 1;
                    end
                end
                done_reg <= 0;
                result <= 0;
            end
            3: begin
                result <= dp[target_i_reg][target_j_reg] >> 16;
                done_reg <= 1;
            end
        endcase
    end
endmodule
assign done = done_reg;
