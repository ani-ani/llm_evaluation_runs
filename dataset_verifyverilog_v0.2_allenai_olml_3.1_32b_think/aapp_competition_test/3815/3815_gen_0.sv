module periodic_sum (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] a,
    input [7:0] b,
    input [1:0] k,
    input [3:0] s,
    output reg [23:0] result,
    output reg done
);

parameter MOD = 16777213;

reg [3:0] state;
reg [23:0] inv_a, b_inv_a, q, sum_period, temp;
reg [7:0] T;
reg [1:0] i;
reg [7:0] exp_cnt;
reg [3:0] substate;

always @(posedge clk) begin
    if (!rst_n) begin
        state <=0;
        inv_a <=0;
        b_inv_a <=0;
        q <=0;
        sum_period <=0;
        T <=0;
        exp_cnt <=0;
        i <=0;
        substate <=0;
        done <=0;
    end else begin
        if (state ==0) begin
            if (start) state <=1;
        end else begin
            case(state)
                1: begin
                    if (exp_cnt ==0) begin
                        exp_cnt <=1;
                    end else if (exp_cnt ==1) begin
                        inv_a <=1;
                        state <=2;
                        exp_cnt <=0;
                    end
                end
                2: begin
                    b_inv_a <= (b * inv_a) % MOD;
                    state <=3;
                end
                3: begin
                    q <= b_inv_a % MOD;
                    state <=4;
                end
                4: begin
                    T <= (n +1) / k;
                    state <=5;
                end
                5: begin
                    i <=0;
                    substate <=0;
                    state <=6;
                end
                6: begin
                    if (i < k) begin
                        sum_period <= (sum_period + ( (s >> i &1) ? a : -a )) % MOD;
                        i <= i +1;
                    end else begin
                        state <=7;
                    end
                end
                7: begin
                    result <= sum_period * T % MOD;
                    done <=1;
                    state <=8;
                end
                8: begin
                    if (start) begin
                        state <=1;
                        done <=0;
                    end
                end
            endcase
        end
    end
endmodule