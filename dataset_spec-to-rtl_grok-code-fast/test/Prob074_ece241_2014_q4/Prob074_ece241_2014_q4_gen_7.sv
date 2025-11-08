module TopModule(
    input clk,
    input x,
    output z
);

    reg q1, q2, q3; // Flip-flops
    wire d1, d2, d3;

    assign d1 = x ^ q1; // XOR with own output
    assign d2 = x & (~q2); // AND with complement
    assign d3 = x | (~q3); // OR with complement
    assign z = ~(q1 | q2 | q3); // NOR gate

    always @(posedge clk) begin
        q1 <= d1;
        q2 <= d2;
        q3 <= d3;
    end

    initial begin
        q1 = 0;
        q2 = 0;
        q3 = 0;
    end

endmodule