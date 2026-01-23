module string_split (
    input [127:0] input_string,
    output logic [15:0][7:0] characters
);

    // Combinational logic to split 128-bit input into 16 8-bit characters
    // Index 0 corresponds to the most significant byte (left-most character)
    assign characters = input_string;

endmodule