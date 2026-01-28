module sum_even_check(
    input [7:0] n,
    output reg result
);

    // Combinational logic to check if n can be expressed as sum of 4 positive even numbers
    // Conditions: n must be even, n >= 8, and n != 10
    always @(*) begin
        if ((n[0] == 1'b0) && (n >= 8'd8) && (n != 8'd10)) begin
            result = 1'b1;
        end else begin
            result = 1'b0;
        end
    end

endmodule