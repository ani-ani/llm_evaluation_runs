module is_happy(
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [2:0] length,
    output is_happy
);

    // Intermediate signals for each window validity
    // Window 0: positions 0, 1, 2 (requires length >= 3)
    wire win0_distinct = (char_0 != char_1) && (char_0 != char_2) && (char_1 != char_2);
    wire win0_valid = (length >= 3) && win0_distinct;

    // Window 1: positions 1, 2, 3 (requires length >= 4)
    wire win1_distinct = (char_1 != char_2) && (char_1 != char_3) && (char_2 != char_3);
    wire win1_valid = (length >= 4) && win1_distinct;

    // Window 2: positions 2, 3, 4 (requires length >= 5)
    wire win2_distinct = (char_2 != char_3) && (char_2 != char_4) && (char_3 != char_4);
    wire win2_valid = (length >= 5) && win2_distinct;

    // Window 3: positions 3, 4, 5 (requires length >= 6)
    wire win3_distinct = (char_3 != char_4) && (char_3 != char_5) && (char_4 != char_5);
    wire win3_valid = (length >= 6) && win3_distinct;

    // Window 4: positions 4, 5, 6 (requires length >= 7)
    wire win4_distinct = (char_4 != char_5) && (char_4 != char_6) && (char_5 != char_6);
    wire win4_valid = (length >= 7) && win4_distinct;

    // Window 5: positions 5, 6, 7 (requires length >= 8)
    wire win5_distinct = (char_5 != char_6) && (char_5 != char_7) && (char_6 != char_7);
    wire win5_valid = (length >= 8) && win5_distinct;

    // String is happy if length >= 3 AND all valid windows are distinct
    assign is_happy = (length >= 3) && 
                     win0_valid && 
                     win1_valid && 
                     win2_valid && 
                     win3_valid && 
                     win4_valid && 
                     win5_valid;

endmodule