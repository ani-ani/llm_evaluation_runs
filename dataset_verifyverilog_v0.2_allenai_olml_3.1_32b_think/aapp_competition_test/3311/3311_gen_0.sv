module exponial_mod (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    output reg [15:0] result,
    output reg done
);

reg [15:0] n_reg, m_reg, result_reg, i_reg;
reg [2:0] state;
reg [15:0] exp_base, exp_exponent, exp_mod, exp_result;
reg [3:0] exp_state;
reg done_reg;

initial begin
    n_reg <= 16'd0;
    m_reg <= 16'd0;
    result_reg <= 16'd0;
    i_reg <= 16'd0;
    state <= 3'b000;
    exp_base <= 16'd0;
    exp_exponent <= 16'd0;
    exp_mod <= 16'd0;
    exp_result <= 16'd0;
    exp_state <= 4'b0000;
    done_reg <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        n_reg <= 16'd0;
        m_reg <= 16'd0;
        result_reg <= 16'd0;
        i_reg <= 16'd0;
        state <= 3'b000;
        exp_base <= 16'd0;
        exp_exponent <= 16'd0;
        exp_mod <= 16'd0;
        exp_result <= 16'd0;
        exp_state <= 4'b0000;
        done_reg <= 1'b0;
    end else begin
        case (state)
            3'b000: // IDLE
                if (start) begin
                    n_reg <= n;
                    m_reg <= m;
                    i_reg <= 16'd2;
                    result_reg <= 16'd1;
                    if (n_reg == 1) begin
                        result_reg <= (m_reg == 1) ? 16'd0 : 16'd1;
                        done_reg <= 1'b1;
                        state <= 3'b100;
                    end else begin
                        state <= 3'b010;
                    end
                end
            3'b010: // LOOP
                if (i_reg > n_reg) begin
                    done_reg <= 1'b1;
                    state <= 3'b100;
                end else begin
                    exp_state <= 4'b0001;
                    exp_base <= i_reg;
                    exp_exponent <= result_reg;
                    exp_mod <= m_reg;
                    exp_result <= 16'd1;
                    state <= 3'b011;
                end
            3'b011: // EXP
                case (exp_state)
                    4'b0001: exp_state <= 4'b0010;
                    4'b0010: begin
                        if (exp_exponent == 16'd0) begin
                            exp_state <= 4'b0011;
                        end else begin
                            if (exp_exponent & 1'b1) begin
                                exp_result <= (exp_result * exp_base) - (exp_mod * ((exp_result * exp_base) / exp_mod));
                            end
                            exp_base <= (exp_base * exp_base) - (exp_mod * ((exp_base * exp_base) / exp_mod));
                            exp_exponent <= exp_exponent >> 1;
                            exp_state <= 4'b0010;
                        end
                    end
                    4'b0011: begin
                        result_reg <= exp_result;
                        i_reg <= i_reg + 16'd1;
                        exp_state <= 4'b0000;
                        state <= 3'b010;
                    end
                endcase
            3'b100: // DONE
                done_reg <= 1'b1;
        endcase
    end
end

assign result = done_reg ? result_reg : 16'd0;
assign done = done_reg;

endmodule