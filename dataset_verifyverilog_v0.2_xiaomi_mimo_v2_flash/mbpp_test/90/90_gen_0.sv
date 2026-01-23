module longest_word_length (
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [7:0] char_8,
    input [7:0] char_9,
    input [7:0] char_10,
    input [7:0] char_11,
    input [7:0] char_12,
    input [7:0] char_13,
    input [7:0] char_14,
    input [7:0] char_15,
    input [7:0] char_16,
    input [7:0] char_17,
    input [7:0] char_18,
    input [7:0] char_19,
    input [7:0] char_20,
    input [7:0] char_21,
    input [7:0] char_22,
    input [7:0] char_23,
    input [7:0] char_24,
    input [7:0] char_25,
    input [7:0] char_26,
    input [7:0] char_27,
    input [7:0] char_28,
    input [7:0] char_29,
    input [7:0] char_30,
    input [7:0] char_31,
    input [7:0] char_32,
    input [7:0] char_33,
    input [7:0] char_34,
    input [7:0] char_35,
    input [7:0] char_36,
    input [7:0] char_37,
    input [7:0] char_38,
    input [7:0] char_39,
    input [7:0] char_40,
    input [7:0] char_41,
    input [7:0] char_42,
    input [7:0] char_43,
    input [7:0] char_44,
    input [7:0] char_45,
    input [7:0] char_46,
    input [7:0] char_47,
    input [7:0] char_48,
    input [7:0] char_49,
    input [7:0] char_50,
    input [7:0] char_51,
    input [7:0] char_52,
    input [7:0] char_53,
    input [7:0] char_54,
    input [7:0] char_55,
    input [7:0] char_56,
    input [7:0] char_57,
    input [7:0] char_58,
    input [7:0] char_59,
    input [7:0] char_60,
    input [7:0] char_61,
    input [7:0] char_62,
    input [7:0] char_63,
    output [3:0] max_length
);

    // Function to compute length of a single word
    function [3:0] word_length;
        input [7:0] c0, c1, c2, c3, c4, c5, c6, c7;
        begin
            if (c0 == 8'h00) word_length = 4'd0;
            else if (c1 == 8'h00) word_length = 4'd1;
            else if (c2 == 8'h00) word_length = 4'd2;
            else if (c3 == 8'h00) word_length = 4'd3;
            else if (c4 == 8'h00) word_length = 4'd4;
            else if (c5 == 8'h00) word_length = 4'd5;
            else if (c6 == 8'h00) word_length = 4'd6;
            else if (c7 == 8'h00) word_length = 4'd7;
            else word_length = 4'd8;
        end
    endfunction

    // Compute lengths for all 8 words
    wire [3:0] len0 = word_length(char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7);
    wire [3:0] len1 = word_length(char_8, char_9, char_10, char_11, char_12, char_13, char_14, char_15);
    wire [3:0] len2 = word_length(char_16, char_17, char_18, char_19, char_20, char_21, char_22, char_23);
    wire [3:0] len3 = word_length(char_24, char_25, char_26, char_27, char_28, char_29, char_30, char_31);
    wire [3:0] len4 = word_length(char_32, char_33, char_34, char_35, char_36, char_37, char_38, char_39);
    wire [3:0] len5 = word_length(char_40, char_41, char_42, char_43, char_44, char_45, char_46, char_47);
    wire [3:0] len6 = word_length(char_48, char_49, char_50, char_51, char_52, char_53, char_54, char_55);
    wire [3:0] len7 = word_length(char_56, char_57, char_58, char_59, char_60, char_61, char_62, char_63);

    // Find maximum among all 8 lengths
    assign max_length = ((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4) ? ((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) : len4) > len5) ? (((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) > len5 ? (((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) : len5) : len5) > len6) ? ((((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) > len5 ? (((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) : len5) > len6 ? ((((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) > len5 ? (((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) : len5) : len6) : len6) > len7) ? (((((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) > len5 ? (((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) > len6 ? ((((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) > len5 ? (((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) : len5) > len6 ? ((((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) > len5 ? (((((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) > len4 ? ((((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3) ? (((((len0 > len1) ? len0 : len1) > len2) ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) > len3 ? (((len0 > len1) ? len0 : len1) > len2 ? (((len0 > len1) ? len0 : len1) > len2 ? ((len0 > len1) ? len0 : len1) : len2) : len2) : len3) : len3) : len4) : len5) : len6) : len6) : len7) : len7;

endmodule