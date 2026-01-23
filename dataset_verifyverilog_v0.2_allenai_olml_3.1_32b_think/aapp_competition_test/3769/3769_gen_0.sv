module func_count (
    input clk,
    input rst_n,
    input start,
    input [15:0] p_in,
    input [15:0] k_in,
    output reg [31:0] result,
    output reg done
);

reg [31:0] p_reg, k_reg;
reg [2:0] state;
reg [31:0] exponent_reg, current_val, counter, order, base_reg, result_exp, result_reg;
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        p_reg <= 0;
        k_reg <= 0;
        state <= 3'b000;
        done_reg <= 0;
        result_reg <= 0;
        exponent_reg <= 0;
        current_val <= 0;
        counter <= 0;
        order <= 0;
        base_reg <= 0;
        result_exp <= 0;
    end else if (start) begin
        p_reg <= {16'b0, p_in};
        k_reg <= {16'b0, k_in};
        state <= 3'b001;
        done_reg <= 0;
        exponent_reg <= 0;
        current_val <= 0;
        counter <= 0;
        order <= 0;
        base_reg <= 0;
        result_exp <= 0;
    end
end

always @(posedge clk) begin
    if (state == 3'b000) begin
        if (start) begin
            state <= 3'b001;
        end
    end else if (state == 3'b001) begin
        if (k_reg == 0) begin
            exponent_reg <= p_reg - 1;
            base_reg <= p_reg;
            result_exp <= 1;
            state <= 3'b003;
        end else if (k_reg == 1) begin
            exponent_reg <= p_reg;
            base_reg <= p_reg;
            result_exp <= 1;
            state <= 3'b003;
        end else begin
            state <= 3'b002;
            current_val <= 1;
            counter <= 1;
        end
    end else if (state == 3'b002) begin
        if (current_val == 1) begin
            order <= counter;
            exponent_reg <= (p_reg - 1) / order;
            base_reg <= p_reg;
            result_exp <= 1;
            state <= 3'b003;
        end else begin
            current_val <= (current_val * k_reg) % p_reg;
            counter <= counter + 1;
        end
    end else if (state == 3'b003) begin
        if (exponent_reg == 0) begin
            result_exp <= 1;
            state <= 3'b004;
        end else begin
            if (exponent_reg & 1) begin
                result_exp <= (result_exp * base_reg) % (1 << 32);
            end
            base_reg <= (base_reg * base_reg) % (1 << 32);
            exponent_reg <= exponent_reg >> 1;
        end
    end else if (state == 3'b004) begin
        done_reg <= 1;
        result_reg <= result_exp;
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule