module max_f_value (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] n,
    input [7:0][15:0] a,
    output reg [31:0] result,
    output reg done
);

reg [2:0] state, next_state;
reg [7:0][15:0] a_reg;
reg [31:0] current_sum1, max_sum1, current_sum2, max_sum2;
reg [2:0] i_count;

parameter IDLE = 3'd0;
parameter LOAD = 3'd1;
parameter PROCESS = 3'd2;
parameter CALC = 3'd3;
parameter DONE = 3'd4;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result <=0;
        done <=0;
        a_reg <= 0;
        i_count <=0;
        current_sum1 <=0;
        max_sum1 <=0;
        current_sum2 <=0;
        max_sum2 <=0;
    end else begin
        state <= next_state;

        if (state == IDLE) begin
            if (start) begin
                next_state <= LOAD;
            end else begin
                next_state <= IDLE;
            end
        end else if (state == LOAD) begin
            if (n < 2 || n > 8) begin
                result <= 0;
                done <=1;
                next_state <= DONE;
            end else begin
                a_reg <= a;
                current_sum1 <=0;
                max_sum1 <=0;
                current_sum2 <=0;
                max_sum2 <=0;
                i_count <=0;
                next_state <= PROCESS;
            end
        end else if (state == PROCESS) begin
            if (i_count < n-1) begin
                integer i = i_count;
                integer diff = a_reg[i] - a_reg[i+1];
                if (diff <0) diff = -diff;
                integer sign = (i % 2 ==0) ? 1 : -1;
                integer element1 = diff * sign;
                integer element2 = -element1;

                integer new_cs1, new_ms1;
                new_cs1 = (element1 > current_sum1 + element1) ? element1 : current_sum1 + element1;
                new_ms1 = (max_sum1 > new_cs1) ? max_sum1 : new_cs1;

                integer new_cs2, new_ms2;
                new_cs2 = (element2 > current_sum2 + element2) ? element2 : current_sum2 + element2;
                new_ms2 = (max_sum2 > new_cs2) ? max_sum2 : new_cs2;

                current_sum1 <= new_cs1;
                max_sum1 <= new_ms1;
                current_sum2 <= new_cs2;
                max_sum2 <= new_ms2;
                i_count <= i_count +1;
                next_state <= PROCESS;
            end else begin
                next_state <= CALC;
            end
        end else if (state == CALC) begin
            result <= (max_sum1 > max_sum2) ? max_sum1 : max_sum2;
            done <=1;
            next_state <= DONE;
        end else if (state == DONE) begin
            next_state <= DONE;
        end
    end
end
endmodule