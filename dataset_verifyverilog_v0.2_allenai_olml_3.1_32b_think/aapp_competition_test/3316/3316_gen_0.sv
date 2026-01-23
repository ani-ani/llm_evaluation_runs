module lottery_probability (
    input clk,
    input rst_n,
    input start,
    input [7:0] m,
    input [7:0] n,
    input [7:0] t,
    input [7:0] p,
    output reg [31:0] result,
    output reg done
);

localparam IDLE = 3'd0;
localparam CALC_KMIN = 3'd1;
localparam COMPUTE_ITER = 3'd2;
localparam COMPUTE_DENOM = 3'd3;
localparam DIVIDE = 3'd4;
localparam DONE = 3'd5;

reg [2:0] state;
reg [7:0] k_min, k_max, current_k;
reg [31:0] numerator, denominator, term;
reg [31:0] const_1_0;
reg done_reg;

function [31:0] compute_comb;
    input [7:0] a, b;
    begin
        if (b > a) return 0;
        if (b == 0 || b == a) return 32'h00010000;
        reg [31:0] comb = 32'h00010000;
        for (int i=1; i<=b; i=i+1) begin
            int val = a - i + 1;
            reg [31:0] temp = comb * (val << 16);
            reg [31:0] divided = temp / i;
            comb = divided >> 16;
        end
        return comb;
    endfunction

function [7:0] ceil_div;
    input [7:0] a, b;
    begin
        return (a + b - 1) / b;
    endfunction

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        k_min <= 8'd0;
        k_max <= 8'd0;
        current_k <= 8'd0;
        numerator <= 32'd0;
        denominator <= 32'd0;
        term <= 32'd0;
        done_reg <= 1'b0;
        result <= 32'd0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= CALC_KMIN;
                k_min <= ceil_div(p, t);
                k_max <= min(p, n);
            end
        end else if (state == CALC_KMIN) begin
            if (k_min > k_max) begin
                state <= DONE;
                done_reg <= 1'b1;
                result <= 32'd0;
            end else begin
                state <= COMPUTE_ITER;
                current_k <= k_min;
            end
        end else if (state == COMPUTE_ITER) begin
            if (current_k > k_max) begin
                state <= COMPUTE_DENOM;
            end else begin
                term <= compute_comb(p, current_k) * compute_comb(m - p, n - current_k);
                numerator <= numerator + (term >> 16);
                current_k <= current_k + 1;
            end
        end else if (state == COMPUTE_DENOM) begin
            denominator <= compute_comb(m, n);
            state <= DIVIDE;
        end else if (state == DIVIDE) begin
            if (denominator == 0) begin
                result <= 32'd0;
            end else begin
                result <= (numerator >> 16) / (denominator >> 16);
            end
            state <= DONE;
            done_reg <= 1'b1;
        end
    end
end

assign done = done_reg;

endmodule