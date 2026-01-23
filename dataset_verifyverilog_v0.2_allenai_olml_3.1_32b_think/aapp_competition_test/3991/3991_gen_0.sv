module subset_sum_solver (
    input clk,
    input rst_n, // active low
    input start,
    input [63:0] x_in [0:7],
    output reg [63:0] result,
    output reg done
);

localparam MOD = 1000000007;
localparam [31:0] coeff [7:0] = {
    32'd999999880,
    32'd999999945,
    32'd999999979,
    32'd999999999,
    32'd8,
    32'd28,
    32'd62,
    32'd127,
};

reg [63:0] x_reg [0:7];
reg [2:0] state;
reg [63:0] sum;
reg [63:0] result;
reg done;
reg [2:0] count;

localparam IDLE = 2'd0;
localparam LOAD = 1;
localparam CALC = 2;

always @(posedge clk) begin
    if (!rst_n) begin
        x_reg <= 0;
        state <= IDLE;
        sum <= 0;
        result <= 0;
        done <=0;
        count <=0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= LOAD;
                x_reg <= x_in;
            end
        end else if (state == LOAD) begin
            state <= CALC;
            count <=7;
        end else if (state == CALC) begin
            if (count >=0) begin
                sum = (sum + (x_reg[count] % MOD) * coeff[count]) % MOD;
                count <= count -1;
            end else begin
                result = sum << 16;
                done <=1;
                state <= IDLE;
            end
        end
    end
end

endmodule