module has_close_elements(
    input [7:0][31:0] numbers,
    input [31:0] threshold,
    output result
);

    // Helper macro for absolute difference calculation
    // For each pair (i, j), compute |numbers[i] - numbers[j]| and compare with threshold
    
    wire [13:0] pair_close; // 14 pairs for 8 elements: 8*7/2 = 28, but we need 8 elements = 28 pairs? No, for 8 elements it's 8*7/2=28 pairs
    // Wait, the requirement says 14 comparisons for 8 elements - this is incorrect mathematically.
    // 8 elements: C(8,2) = 28 pairs. Let's implement 28 pairs to be correct.
    // Actually, let me recalculate: The requirement mentions "14 comparisons for 8 elements" 
    // which suggests maybe they meant 4 elements? But the input has 8 elements.
    // I'll implement for all 8 elements properly: 28 pairs total.
    
    // Pair (0,1)
    wire [31:0] diff_01 = numbers[0] - numbers[1];
    wire [31:0] abs_01 = diff_01[31] ? (~diff_01 + 1'b1) : diff_01;
    assign pair_close[0] = (abs_01 < threshold);
    
    // Pair (0,2)
    wire [31:0] diff_02 = numbers[0] - numbers[2];
    wire [31:0] abs_02 = diff_02[31] ? (~diff_02 + 1'b1) : diff_02;
    assign pair_close[1] = (abs_02 < threshold);
    
    // Pair (0,3)
    wire [31:0] diff_03 = numbers[0] - numbers[3];
    wire [31:0] abs_03 = diff_03[31] ? (~diff_03 + 1'b1) : diff_03;
    assign pair_close[2] = (abs_03 < threshold);
    
    // Pair (0,4)
    wire [31:0] diff_04 = numbers[0] - numbers[4];
    wire [31:0] abs_04 = diff_04[31] ? (~diff_04 + 1'b1) : diff_04;
    assign pair_close[3] = (abs_04 < threshold);
    
    // Pair (0,5)
    wire [31:0] diff_05 = numbers[0] - numbers[5];
    wire [31:0] abs_05 = diff_05[31] ? (~diff_05 + 1'b1) : diff_05;
    assign pair_close[4] = (abs_05 < threshold);
    
    // Pair (0,6)
    wire [31:0] diff_06 = numbers[0] - numbers[6];
    wire [31:0] abs_06 = diff_06[31] ? (~diff_06 + 1'b1) : diff_06;
    assign pair_close[5] = (abs_06 < threshold);
    
    // Pair (0,7)
    wire [31:0] diff_07 = numbers[0] - numbers[7];
    wire [31:0] abs_07 = diff_07[31] ? (~diff_07 + 1'b1) : diff_07;
    assign pair_close[6] = (abs_07 < threshold);
    
    // Pair (1,2)
    wire [31:0] diff_12 = numbers[1] - numbers[2];
    wire [31:0] abs_12 = diff_12[31] ? (~diff_12 + 1'b1) : diff_12;
    assign pair_close[7] = (abs_12 < threshold);
    
    // Pair (1,3)
    wire [31:0] diff_13 = numbers[1] - numbers[3];
    wire [31:0] abs_13 = diff_13[31] ? (~diff_13 + 1'b1) : diff_13;
    assign pair_close[8] = (abs_13 < threshold);
    
    // Pair (1,4)
    wire [31:0] diff_14 = numbers[1] - numbers[4];
    wire [31:0] abs_14 = diff_14[31] ? (~diff_14 + 1'b1) : diff_14;
    assign pair_close[9] = (abs_14 < threshold);
    
    // Pair (1,5)
    wire [31:0] diff_15 = numbers[1] - numbers[5];
    wire [31:0] abs_15 = diff_15[31] ? (~diff_15 + 1'b1) : diff_15;
    assign pair_close[10] = (abs_15 < threshold);
    
    // Pair (1,6)
    wire [31:0] diff_16 = numbers[1] - numbers[6];
    wire [31:0] abs_16 = diff_16[31] ? (~diff_16 + 1'b1) : diff_16;
    assign pair_close[11] = (abs_16 < threshold);
    
    // Pair (1,7)
    wire [31:0] diff_17 = numbers[1] - numbers[7];
    wire [31:0] abs_17 = diff_17[31] ? (~diff_17 + 1'b1) : diff_17;
    assign pair_close[12] = (abs_17 < threshold);
    
    // Pair (2,3)
    wire [31:0] diff_23 = numbers[2] - numbers[3];
    wire [31:0] abs_23 = diff_23[31] ? (~diff_23 + 1'b1) : diff_23;
    assign pair_close[13] = (abs_23 < threshold);
    
    // Pair (2,4)
    wire [31:0] diff_24 = numbers[2] - numbers[4];
    wire [31:0] abs_24 = diff_24[31] ? (~diff_24 + 1'b1) : diff_24;
    wire close_24 = (abs_24 < threshold);
    
    // Pair (2,5)
    wire [31:0] diff_25 = numbers[2] - numbers[5];
    wire [31:0] abs_25 = diff_25[31] ? (~diff_25 + 1'b1) : diff_25;
    wire close_25 = (abs_25 < threshold);
    
    // Pair (2,6)
    wire [31:0] diff_26 = numbers[2] - numbers[6];
    wire [31:0] abs_26 = diff_26[31] ? (~diff_26 + 1'b1) : diff_26;
    wire close_26 = (abs_26 < threshold);
    
    // Pair (2,7)
    wire [31:0] diff_27 = numbers[2] - numbers[7];
    wire [31:0] abs_27 = diff_27[31] ? (~diff_27 + 1'b1) : diff_27;
    wire close_27 = (abs_27 < threshold);
    
    // Pair (3,4)
    wire [31:0] diff_34 = numbers[3] - numbers[4];
    wire [31:0] abs_34 = diff_34[31] ? (~diff_34 + 1'b1) : diff_34;
    wire close_34 = (abs_34 < threshold);
    
    // Pair (3,5)
    wire [31:0] diff_35 = numbers[3] - numbers[5];
    wire [31:0] abs_35 = diff_35[31] ? (~diff_35 + 1'b1) : diff_35;
    wire close_35 = (abs_35 < threshold);
    
    // Pair (3,6)
    wire [31:0] diff_36 = numbers[3] - numbers[6];
    wire [31:0] abs_36 = diff_36[31] ? (~diff_36 + 1'b1) : diff_36;
    wire close_36 = (abs_36 < threshold);
    
    // Pair (3,7)
    wire [31:0] diff_37 = numbers[3] - numbers[7];
    wire [31:0] abs_37 = diff_37[31] ? (~diff_37 + 1'b1) : diff_37;
    wire close_37 = (abs_37 < threshold);
    
    // Pair (4,5)
    wire [31:0] diff_45 = numbers[4] - numbers[5];
    wire [31:0] abs_45 = diff_45[31] ? (~diff_45 + 1'b1) : diff_45;
    wire close_45 = (abs_45 < threshold);
    
    // Pair (4,6)
    wire [31:0] diff_46 = numbers[4] - numbers[6];
    wire [31:0] abs_46 = diff_46[31] ? (~diff_46 + 1'b1) : diff_46;
    wire close_46 = (abs_46 < threshold);
    
    // Pair (4,7)
    wire [31:0] diff_47 = numbers[4] - numbers[7];
    wire [31:0] abs_47 = diff_47[31] ? (~diff_47 + 1'b1) : diff_47;
    wire close_47 = (abs_47 < threshold);
    
    // Pair (5,6)
    wire [31:0] diff_56 = numbers[5] - numbers[6];
    wire [31:0] abs_56 = diff_56[31] ? (~diff_56 + 1'b1) : diff_56;
    wire close_56 = (abs_56 < threshold);
    
    // Pair (5,7)
    wire [31:0] diff_57 = numbers[5] - numbers[7];
    wire [31:0] abs_57 = diff_57[31] ? (~diff_57 + 1'b1) : diff_57;
    wire close_57 = (abs_57 < threshold);
    
    // Pair (6,7)
    wire [31:0] diff_67 = numbers[6] - numbers[7];
    wire [31:0] abs_67 = diff_67[31] ? (~diff_67 + 1'b1) : diff_67;
    wire close_67 = (abs_67 < threshold);
    
    // OR all 28 comparisons together
    assign result = (|pair_close) | close_24 | close_25 | close_26 | close_27 |
                    close_34 | close_35 | close_36 | close_37 |
                    close_45 | close_46 | close_47 |
                    close_56 | close_57 |
                    close_67;

endmodule