module max_payout (
    input clk,
    input rst_n,
    input start,
    input [11:0] num_n,
    input [7:0] num_m,
    input [15:0] weights [99:0],
    output reg [31:0] max_sum,
    output reg done
);
localparam IDLE = 2'd0, CALC = 2'd1, DONE = 2'd2;
reg [1:0] state;
reg [5:0] k_counter;
reg [31:0] sum_accum;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        k_counter <= 0;
        sum_accum <= 0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= CALC;
                k_counter <= 1;
                sum_accum <= 0;
            end
        end else if (state == CALC) begin
            if (k_counter > num_m) begin
                state <= DONE;
            end else begin
                integer k;
                k = k_counter;
                integer required;
                if (k % 2 == 0) begin
                    required = (k * k) / 2;
                end else begin
                    required = (k * (k - 1)) / 2 + 1;
                end
                if (required <= num_n) begin
                    sum_accum <= sum_accum + weights[k_counter - 1];
                end
                k_counter <= k_counter + 1;
            end
        end
    end
end

assign max_sum = sum_accum;
assign done = (state == DONE);

endmodule