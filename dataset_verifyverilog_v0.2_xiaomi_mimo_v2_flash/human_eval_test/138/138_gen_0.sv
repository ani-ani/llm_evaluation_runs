module sum_even (
    input [7:0] n,
    output result
);

    // Result is 1 if n >= 8 and n is even (LSB is 0)
    assign result = (n >= 8) && (n[0] == 1'b0);

endmodule