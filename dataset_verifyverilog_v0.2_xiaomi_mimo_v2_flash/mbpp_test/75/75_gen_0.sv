module tuple_divisible_filter(
    input [7:0] tuple_0_elem_0,
    input [7:0] tuple_0_elem_1,
    input [7:0] tuple_0_elem_2,
    input [7:0] tuple_1_elem_0,
    input [7:0] tuple_1_elem_1,
    input [7:0] tuple_1_elem_2,
    input [7:0] tuple_2_elem_0,
    input [7:0] tuple_2_elem_1,
    input [7:0] tuple_2_elem_2,
    input [7:0] K,
    output [2:0] valid
);

    // Intermediate signals for modulo results
    wire [7:0] mod_0_0;
    wire [7:0] mod_0_1;
    wire [7:0] mod_0_2;
    wire [7:0] mod_1_0;
    wire [7:0] mod_1_1;
    wire [7:0] mod_1_2;
    wire [7:0] mod_2_0;
    wire [7:0] mod_2_1;
    wire [7:0] mod_2_2;

    // Compute modulo operations
    assign mod_0_0 = tuple_0_elem_0 % K;
    assign mod_0_1 = tuple_0_elem_1 % K;
    assign mod_0_2 = tuple_0_elem_2 % K;
    assign mod_1_0 = tuple_1_elem_0 % K;
    assign mod_1_1 = tuple_1_elem_1 % K;
    assign mod_1_2 = tuple_1_elem_2 % K;
    assign mod_2_0 = tuple_2_elem_0 % K;
    assign mod_2_1 = tuple_2_elem_1 % K;
    assign mod_2_2 = tuple_2_elem_2 % K;

    // Compute valid bits: 1 if all elements in tuple are divisible by K
    assign valid[0] = (mod_0_0 == 8'b0) & (mod_0_1 == 8'b0) & (mod_0_2 == 8'b0);
    assign valid[1] = (mod_1_0 == 8'b0) & (mod_1_1 == 8'b0) & (mod_1_2 == 8'b0);
    assign valid[2] = (mod_2_0 == 8'b0) & (mod_2_1 == 8'b0) & (mod_2_2 == 8'b0);

endmodule