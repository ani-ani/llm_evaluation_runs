module TopModule(
    input  reg [3:0] x,
    input  reg [3:0] y,
    output reg [4:0] sum
);
    always_comb begin
        logic [4:0] carry;
        carry[0] = 1'b0;
        for (int i = 0; i < 4; i++) begin
            sum[i] = x[i] ^ y[i] ^ carry[i];
            carry[i+1] = (x[i] & y[i]) | (x[i] & carry[i]) | (y[i] & carry[i]);
        end
        sum[4] = carry[4];
    end
endmodule