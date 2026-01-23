module table_tennis(
    input signed [31:0] k,
    input signed [31:0] a,
    input signed [31:0] b,
    output reg signed [31:0] result
);

    always @(*) begin
        // Division results
        reg signed [31:0] X;
        reg signed [31:0] Y;
        reg signed [31:0] rem_a;
        reg signed [31:0] rem_b;
        
        X = a / k;
        Y = b / k;
        rem_a = a % k;
        rem_b = b % k;
        
        // Check conditions
        if (((rem_a != 0) && (Y == 0)) || ((rem_b != 0) && (X == 0))) begin
            result = -1;
        end else begin
            result = X + Y;
        end
    end

endmodule