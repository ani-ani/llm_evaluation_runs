module list_combinations(
    input  [3:0][1:0]  elements,
    output [15:0][3:0] all_combinations
);

    // Each index N (0-15) corresponds directly to a 4-bit mask pattern.
    // Bit i of all_combinations[N] is set if element i is present in the subset.

    assign all_combinations[0]  = 4'b0000;
    assign all_combinations[1]  = 4'b0001;
    assign all_combinations[2]  = 4'b0010;
    assign all_combinations[3]  = 4'b0011;
    assign all_combinations[4]  = 4'b0100;
    assign all_combinations[5]  = 4'b0101;
    assign all_combinations[6]  = 4'b0110;
    assign all_combinations[7]  = 4'b0111;
    assign all_combinations[8]  = 4'b1000;
    assign all_combinations[9]  = 4'b1001;
    assign all_combinations[10] = 4'b1010;
    assign all_combinations[11] = 4'b1011;
    assign all_combinations[12] = 4'b1100;
    assign all_combinations[13] = 4'b1101;
    assign all_combinations[14] = 4'b1110;
    assign all_combinations[15] = 4'b1111;

endmodule