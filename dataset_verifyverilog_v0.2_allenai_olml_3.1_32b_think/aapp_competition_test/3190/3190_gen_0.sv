module voodoo_average (
    input clk,
    input rst_n, // active-low
    input start,
    input [15:0] valid_length,
    input [31:0] price_i,
    input [31:0] P,
    output reg [31:0] result,
    output reg done,
    output reg input_ready
);

parameter IDLE = 2'd0;
parameter LOAD = 2'd1;
parameter COMPUTE = 2'd2;
parameter DONE_STATE = 2'd3;

reg [1:0] state;
reg [15:0] stored_length;
reg [15:0] count_prices;
reg [15:0] prices [0:15];
reg [31:0] total_result;
reg [15:0] i, j;
reg [4:0] sum_high; // 5 bits, max 15
reg [31:0] sum_low;
reg [15:0] max_index;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        stored_length <=0;
        count_prices <=0;
        prices <=0;
        total_result <=0;
        i <=0;
        j <=0;
        sum_high <=0;
        sum_low <=0;
        max_index <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD;
                    stored_length <= valid_length;
                    count_prices <=0;
                end
                input_ready <= 1'b1;
            end
            LOAD: begin
                if (count_prices < stored_length) begin
                    prices[count_prices] <= price_i;
                    count_prices <= count_prices +1;
                    state <= LOAD;
                    input_ready <= 1'b1;
                end else begin
                    state <= COMPUTE;
                    i <=0;
                    j <=0;
                    sum_high <=0;
                    sum_low <=0;
                    total_result <=0;
                    max_index <= stored_length -1;
                    input_ready <=1'b0;
                end
            end
            COMPUTE: begin
                input_ready <= 1'b0;
                if (i > max_index) begin
                    done <=1;
                    state <= DONE_STATE;
                end else begin
                    if (j < i) begin
                        sum_high <=0;
                        sum_low <=0;
                        j <= i;
                    end else if (j <= max_index) begin
                        wire [31:0] temp_sum_low = sum_low + prices[j];
                        wire carry = temp_sum_low < prices[j]; // Unsigned overflow

                        sum_low <= temp_sum_low;
                        sum_high <= sum_high + carry;

                        logic [36:0] threshold_37 = P * (j - i +1);

                        if ({0, {sum_high, sum_low}} >= threshold_37) begin
                            total_result <= total_result +1;
                        end

                        j <= j +1;
                    end else begin
                        i <= i +1;
                        j <= i;
                    end
                end
            end
            DONE_STATE: begin
                state <= DONE_STATE;
                done <=1;
                input_ready <=1'b0;
            end
        endcase
    end
end

assign result = total_result;
