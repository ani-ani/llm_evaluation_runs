module penguin_walkways (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [3:0] k,
    output reg [31:0] result,
    output reg done
);

reg [2:0] state_reg;
reg [15:0] n_reg;
reg [3:0] k_reg;
reg [31:0] factor_a, factor_b;
reg [31:0] temp_result, temp_base, temp_exp;
reg [31:0] final_result;
reg done_reg;

localparam M = 1000000007;
localparam IDLE = 3'd0, SETUP_A = 3'd1, CALC_A = 3'd2, SETUP_B = 3'd3, CALC_B = 3'd4, MULTIPLY = 3'd5, DONE = 3'd6;

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        n_reg <= 16'd0;
        k_reg <= 4'd0;
        factor_a <= 32'd0;
        factor_b <= 32'd0;
        temp_result <= 32'd0;
        temp_base <= 32'd0;
        temp_exp <= 32'd0;
        final_result <= 32'd0;
        done_reg <= 1'b0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) state_reg <= SETUP_A;
                else state_reg <= IDLE;
            end
            SETUP_A: begin
                n_reg <= n;
                k_reg <= k;
                temp_result <= 1;
                temp_base <= k_reg;
                temp_exp <= k_reg - 1;
                state_reg <= CALC_A;
            end
            CALC_A: begin
                if (temp_exp == 0) begin
                    factor_a <= temp_result;
                    state_reg <= SETUP_B;
                end else begin
                    if (temp_exp & 1) temp_result <= (temp_result * temp_base) % M;
                    temp_base <= (temp_base * temp_base) % M;
                    temp_exp <= temp_exp >> 1;
                    state_reg <= CALC_A;
                end
            end
            SETUP_B: begin
                temp_result <= 1;
                temp_base <= n_reg - k_reg;
                temp_exp <= n_reg - k_reg;
                state_reg <= CALC_B;
            end
            CALC_B: begin
                if (temp_exp == 0) begin
                    factor_b <= temp_result;
                    state_reg <= MULTIPLY;
                end else begin
                    if (temp_exp & 1) temp_result <= (temp_result * temp_base) % M;
                    temp_base <= (temp_base * temp_base) % M;
                    temp_exp <= temp_exp >> 1;
                    state_reg <= CALC_B;
                end
            end
            MULTIPLY: begin
                final_result <= (factor_a * factor_b) % M;
                state_reg <= DONE;
            end
            DONE: begin
                done_reg <= 1'b1;
                state_reg <= DONE;
            end
        endcase
    end
end

assign result = final_result;
assign done = done_reg;
endmodule