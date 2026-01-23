module generate_integers (
    input [7:0] a,
    input [7:0] b,
    output [7:0] result,
    output [7:0] distance
);

    // Internal signal to store the bounded input value
    reg [7:0] a_bounded;

    // Combinational logic to bound input a to [0, 99]
    always @(*) begin
        if (a > 8'd99) begin
            a_bounded = 8'd99;
        end else begin
            a_bounded = a;
        end
    end

    // Combinational logic for result and distance
    assign result = (a_bounded[0] == 1'b0) ? a_bounded : // Even
                    (a_bounded == 8'd0) ? 8'd2 :        // Odd, boundary low
                    (a_bounded == 8'd99) ? 8'd98 :       // Odd, boundary high
                    (a_bounded - 8'd1);                 // Odd, standard

    assign distance = (a_bounded[0] == 1'b0) ? 8'd0 :    // Even
                     (a_bounded == 8'd0) ? 8'd2 :       // Odd, boundary low
                     8'd1;                              // Odd, standard (includes a=99 case which is distance 1)

endmodule