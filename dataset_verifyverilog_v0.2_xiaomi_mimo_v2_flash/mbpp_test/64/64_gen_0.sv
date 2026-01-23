module sort_tuples (
    input  [15:0] tuple_0,
    input  [15:0] tuple_1,
    input  [15:0] tuple_2,
    input  [15:0] tuple_3,
    output [15:0] sorted_0,
    output [15:0] sorted_1,
    output [15:0] sorted_2,
    output [15:0] sorted_3
);

    // Stage 1: Compare (0,1) and (2,3)
    wire [15:0] s1_0, s1_1, s1_2, s1_3;

    // Compare (0,1)
    assign s1_0 = (tuple_0[15:8] <= tuple_1[15:8]) ? tuple_0 : tuple_1;
    assign s1_1 = (tuple_0[15:8] <= tuple_1[15:8]) ? tuple_1 : tuple_0;

    // Compare (2,3)
    assign s1_2 = (tuple_2[15:8] <= tuple_3[15:8]) ? tuple_2 : tuple_3;
    assign s1_3 = (tuple_2[15:8] <= tuple_3[15:8]) ? tuple_3 : tuple_2;

    // Stage 2: Compare (1,2)
    wire [15:0] s2_1, s2_2;
    wire [15:0] s2_0 = s1_0; // Pass through
    wire [15:0] s2_3 = s1_3; // Pass through

    assign s2_1 = (s1_1[15:8] <= s1_2[15:8]) ? s1_1 : s1_2;
    assign s2_2 = (s1_1[15:8] <= s1_2[15:8]) ? s1_2 : s1_1;

    // Stage 3: Compare (0,1) and (2,3)
    // Output wires
    wire [15:0] out_0, out_1, out_2, out_3;

    // Compare (0,1)
    assign out_0 = (s2_0[15:8] <= s2_1[15:8]) ? s2_0 : s2_1;
    assign out_1 = (s2_0[15:8] <= s2_1[15:8]) ? s2_1 : s2_0;

    // Compare (2,3)
    assign out_2 = (s2_2[15:8] <= s2_3[15:8]) ? s2_2 : s2_3;
    assign out_3 = (s2_2[15:8] <= s2_3[15:8]) ? s2_3 : s2_2;

    // Assign outputs
    assign sorted_0 = out_0;
    assign sorted_1 = out_1;
    assign sorted_2 = out_2;
    assign sorted_3 = out_3;

endmodule