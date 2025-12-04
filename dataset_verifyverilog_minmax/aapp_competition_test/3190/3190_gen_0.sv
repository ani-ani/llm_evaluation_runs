module doll_average_counter (
    input [15:0] p_value,
    input [7:0][15:0] prices,
    output [5:0] count
);

    // Compute thresholds (32-bit)
    wire [31:0] t1, t2, t3, t4, t5, t6, t7, t8;
    assign t1 = p_value;
    assign t2 = t1 << 1;
    assign t3 = t1 + t2;
    assign t4 = t1 << 2;
    assign t5 = t4 + t1;
    assign t6 = t4 + t2;
    assign t7 = (t1 << 3) - t1;
    assign t8 = t1 << 3;

    // Compute the sums (32-bit)
    wire [31:0] s00, s01, s02, s03, s04, s05, s06, s07;
    wire [31:0] s11, s12, s13, s14, s15, s16, s17;
    wire [31:0] s22, s23, s24, s25, s26, s27;
    wire [31:0] s33, s34, s35, s36, s37;
    wire [31:0] s44, s45, s46, s47;
    wire [31:0] s55, s56, s57;
    wire [31:0] s66, s67;
    wire [31:0] s77;

    // s00 to s07
    assign s00 = prices[0];
    assign s01 = prices[0] + prices[1];
    assign s02 = prices[0] + prices[1] + prices[2];
    assign s03 = prices[0] + prices[1] + prices[2] + prices[3];
    assign s04 = prices[0] + prices[1] + prices[2] + prices[3] + prices[4];
    assign s05 = prices[0] + prices[1] + prices[2] + prices[3] + prices[4] + prices[5];
    assign s06 = prices[0] + prices[1] + prices[2] + prices[3] + prices[4] + prices[5] + prices[6];
    assign s07 = prices[0] + prices[1] + prices[2] + prices[3] + prices[4] + prices[5] + prices[6] + prices[7];

    // s11 to s17
    assign s11 = prices[1];
    assign s12 = prices[1] + prices[2];
    assign s13 = prices[1] + prices[2] + prices[3];
    assign s14 = prices[1] + prices[2] + prices[3] + prices[4];
    assign s15 = prices[1] + prices[2] + prices[3] + prices[4] + prices[5];
    assign s16 = prices[1] + prices[2] + prices[3] + prices[4] + prices[5] + prices[6];
    assign s17 = prices[1] + prices[2] + prices[3] + prices[4] + prices[5] + prices[6] + prices[7];

    // s22 to s27
    assign s22 = prices[2];
    assign s23 = prices[2] + prices[3];
    assign s24 = prices[2] + prices[3] + prices[4];
    assign s25 = prices[2] + prices[3] + prices[4] + prices[5];
    assign s26 = prices[2] + prices[3] + prices[4] + prices[5] + prices[6];
    assign s27 = prices[2] + prices[3] + prices[4] + prices[5] + prices[6] + prices[7];

    // s33 to s37
    assign s33 = prices[3];
    assign s34 = prices[3] + prices[4];
    assign s35 = prices[3] + prices[4] + prices[5];
    assign s36 = prices[3] + prices[4] + prices[5] + prices[6];
    assign s37 = prices[3] + prices[4] + prices[5] + prices[6] + prices[7];

    // s44 to s47
    assign s44 = prices[4];
    assign s45 = prices[4] + prices[5];
    assign s46 = prices[4] + prices[5] + prices[6];
    assign s47 = prices[4] + prices[5] + prices[6] + prices[7];

    // s55 to s57
    assign s55 = prices[5];
    assign s56 = prices[5] + prices[6];
    assign s57 = prices[5] + prices[6] + prices[7];

    // s66, s67
    assign s66 = prices[6];
    assign s67 = prices[6] + prices[7];

    // s77
    assign s77 = prices[7];

    // Comparisons (1 bit each)
    wire c00, c01, c02, c03, c04, c05, c06, c07;
    wire c11, c12, c13, c14, c15, c16, c17;
    wire c22, c23, c24, c25, c26, c27;
    wire c33, c34, c35, c36, c37;
    wire c44, c45, c46, c47;
    wire c55, c56, c57;
    wire c66, c67;
    wire c77;

    assign c00 = (s00 >= t1);
    assign c01 = (s01 >= t2);
    assign c02 = (s02 >= t3);
    assign c03 = (s03 >= t4);
    assign c04 = (s04 >= t5);
    assign c05 = (s05 >= t6);
    assign c06 = (s06 >= t7);
    assign c07 = (s07 >= t8);

    assign c11 = (s11 >= t1);
    assign c12 = (s12 >= t2);
    assign c13 = (s13 >= t3);
    assign c14 = (s14 >= t4);
    assign c15 = (s15 >= t5);
    assign c16 = (s16 >= t6);
    assign c17 = (s17 >= t7);

    assign c22 = (s22 >= t1);
    assign c23 = (s23 >= t2);
    assign c24 = (s24 >= t3);
    assign c25 = (s25 >= t4);
    assign c26 = (s26 >= t5);
    assign c27 = (s27 >= t6);

    assign c33 = (s33 >= t1);
    assign c34 = (s34 >= t2);
    assign c35 = (s35 >= t3);
    assign c36 = (s36 >= t4);
    assign c37 = (s37 >= t5);

    assign c44 = (s44 >= t1);
    assign c45 = (s45 >= t2);
    assign c46 = (s46 >= t3);
    assign c47 = (s47 >= t4);

    assign c55 = (s55 >= t1);
    assign c56 = (s56 >= t2);
    assign c57 = (s57 >= t3);

    assign c66 = (s66 >= t1);
    assign c67 = (s67 >= t2);

    assign c77 = (s77 >= t1);

    // Count
    assign count = 
        c00 + c11 + c22 + c33 + c44 + c55 + c66 + c77
      + c01 + c12 + c23 + c34 + c45 + c56 + c67
      + c02 + c13 + c24 + c35 + c46 + c57
      + c03 + c14 + c25 + c36 + c47
      + c04 + c15 + c26 + c37
      + c05 + c16 + c27
      + c06 + c17
      + c07;

endmodule