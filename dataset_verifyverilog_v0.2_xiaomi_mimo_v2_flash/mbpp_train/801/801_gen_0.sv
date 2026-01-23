module three_equal_counter(
    input signed [7:0] x,
    input signed [7:0] y,
    input signed [7:0] z,
    output reg [2:0] count
);

    always @(*) begin
        // Determine equality flags
        // Use separate wires/vars for clarity and synthesis
        // Inputs are reg type per instructions, comparisons are simple bitwise
        
        // Comparator logic
        // All three equal
        if (x == y && y == z) begin
            count = 3'd3;
        // Exactly two equal
        end else if (x == y || y == z || x == z) begin
            count = 3'd2;
        // All distinct
        end else begin
            count = 3'd0;
        end
    end

endmodule