module ExtractFirst (
    input [7:0] sublists [0:3][0:7],
    output [7:0] first_elements [0:3]
);

    // Combinational logic to extract the first element of each sublist
    assign first_elements[0] = sublists[0][0];
    assign first_elements[1] = sublists[1][0];
    assign first_elements[2] = sublists[2][0];
    assign first_elements[3] = sublists[3][0];

endmodule
