module TopModule(
    input  clk,
    input  x,
    output z
);

    logic q1, q2, q3;

    always @(posedge clk) begin
        q1 <= x ^ q1;
        q2 <= x & ~q2;
        q3 <= x | ~q3;
    end

    assign z = ~(q1 | q2 | q3);

endmodule