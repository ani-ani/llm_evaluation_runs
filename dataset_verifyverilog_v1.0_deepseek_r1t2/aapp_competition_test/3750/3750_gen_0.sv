module table_tennis(
    input signed [31:0] k,
    input signed [31:0] a,
    input signed [31:0] b,
    output reg signed [31:0] result
);
    reg signed [31:0] X, Y;
    reg signed [31:0] rem_a, rem_b;

    always @(*) begin
        X = a / k;
        Y = b / k;
        rem_a = a % k;
        rem_b = b % k;
        
        if ((rem_a != 32'sb0 && Y == 32'sb0) || (rem_b != 32'sb0 && X == 32'sb0)) begin
            result = -32'sd1;
        end else begin
            result = X + Y;
        end
    end
endmodule