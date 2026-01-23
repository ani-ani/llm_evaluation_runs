module casino_profit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] x,
    input wire [15:0] p,
    output reg [31:0] profit,
    output reg done
);

    localparam S_IDLE = 4'd0;
    localparam S_INIT = 4'd1;
    localparam S_RESET_K = 4'd2;
    localparam S_LOAD_PROB = 4'd3;
    localparam S_COMPUTE_PROFIT = 4'd4;
    localparam S_NEXT_K = 4'd5;
    localparam S_UPDATE_MAX = 4'd6;
    localparam S_NEXT_N = 4'd7;
    localparam S_DONE = 4'd8;

    localparam MAX_N = 64;
    localparam Q16_16 = 65536;

    reg [3:0] state;
    reg [7:0] n;
    reg [7:0] k;
    reg [31:0] prob;
    reg [31:0] accum;
    reg [31:0] max_profit;
    reg [31:0] p_frac;
    reg [31:0] one_minus_p_frac;
    reg [31:0] x_frac;

    function [31:0] mul_fixed;
        input [31:0] a, b;
        begin
            mul_fixed = (a * b) >> 16;
        end
    endfunction

    function [31:0] add_fixed;
        input [31:0] a, b;
        begin
            add_fixed = a + b;
        end
    endfunction

    function [31:0] compute_profit;
        input [7:0] k_val, n_val;
        input [31:0] x_frac_reg;
        reg signed [31:0] net;
        reg [31:0] loss;
        reg [31:0] refund;
        begin
            net = (k_val << 1) - n_val;
            if (net >= 0) begin
                compute_profit = net << 16;
            end else begin
                loss = -net;
                refund = mul_fixed(x_frac_reg, loss << 16);
                compute_profit = (net << 16) + refund;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            profit <= 32'd0;
            n <= 8'd0;
            k <= 8'd0;
            prob <= 32'd0;
            accum <= 32'd0;
            max_profit <= 32'd0;
            p_frac <= 32'd0;
            one_minus_p_frac <= 32'd0;
            x_frac <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        p_frac <= p * 256;
                        one_minus_p_frac <= (256*256 - p * 256);
                        x_frac <= (x * 256) * 256;
                        max_profit <= 32'd0;
                        state <= S_INIT;
                    end
                end
                
                S_INIT: begin
                    n <= 8'd1;
                    state <= S_RESET_K;
                end
                
                S_RESET_K: begin
                    k <= 8'd0;
                    prob <= Q16_16;
                    accum <= 32'd0;
                    state <= S_LOAD_PROB;
                end
                
                S_LOAD_PROB: begin
                    state <= S_COMPUTE_PROFIT;
                end
                
                S_COMPUTE_PROFIT: begin
                    accum <= add_fixed(accum, mul_fixed(prob, compute_profit(k, n, x_frac)));
                    state <= S_NEXT_K;
                end
                
                S_NEXT_K: begin
                    if (k < n) begin
                        k <= k + 8'd1;
                        prob <= mul_fixed(mul_fixed(prob, p_frac), (n - k) * Q16_16 / (k + 8'd1));
                        state <= S_LOAD_PROB;
                    end else begin
                        state <= S_UPDATE_MAX;
                    end
                end
                
                S_UPDATE_MAX: begin
                    if (accum > max_profit) begin
                        max_profit <= accum;
                    end
                    if (n < MAX_N) begin
                        n <= n + 8'd1;
                        state <= S_RESET_K;
                    end else begin
                        state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    profit <= (max_profit[31] == 1'b0) ? max_profit : 32'd0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule