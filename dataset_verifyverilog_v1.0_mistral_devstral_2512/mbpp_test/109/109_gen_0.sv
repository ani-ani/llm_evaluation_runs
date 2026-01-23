module odd_Equivalent(
    input [7:0] binary_string,
    output [3:0] count
);
    wire [3:0] count;
    assign count = binary_string[0] + binary_string[1] + binary_string[2] + binary_string[3] + binary_string[4] + binary_string[5] + binary_string[6] + binary_string[7];
endmodule