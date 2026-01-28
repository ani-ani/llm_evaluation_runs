module max_of_two (
    input signed [7:0] a,
    input signed [7:0] b,
    output reg signed [7:0] max_result
);

    // Combinational logic for maximum computation
    // Using signed comparison operator for correct handling of negative values
    always @(*) begin
        if (a >= b) begin
            max_result = a;
        end else begin
            max_result = b;
        end
    end

endmodule