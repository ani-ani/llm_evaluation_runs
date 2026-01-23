module longest_word_length (
  input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
  input [7:0] char_8, char_9, char_10, char_11, char_12, char_13, char_14, char_15,
  input [7:0] char_16, char_17, char_18, char_19, char_20, char_21, char_22, char_23,
  input [7:0] char_24, char_25, char_26, char_27, char_28, char_29, char_30, char_31,
  input [7:0] char_32, char_33, char_34, char_35, char_36, char_37, char_38, char_39,
  input [7:0] char_40, char_41, char_42, char_43, char_44, char_45, char_46, char_47,
  input [7:0] char_48, char_49, char_50, char_51, char_52, char_53, char_54, char_55,
  input [7:0] char_56, char_57, char_58, char_59, char_60, char_61, char_62, char_63,
  output [3:0] max_length
);

  wire [3:0] len0, len1, len2, len3, len4, len5, len6, len7;

  // Word 0 length calculation
  assign len0 = (char_0 == 8'h00) ? 4'd0 :
                (char_1 == 8'h00) ? 4'd1 :
                (char_2 == 8'h00) ? 4'd2 :
                (char_3 == 8'h00) ? 4'd3 :
                (char_4 == 8'h00) ? 4'd4 :
                (char_5 == 8'h00) ? 4'd5 :
                (char_6 == 8'h00) ? 4'd6 :
                (char_7 == 8'h00) ? 4'd7 : 4'd8;

  // Word 1 length calculation
  assign len1 = (char_8 == 8'h00) ? 4'd0 :
                (char_9 == 8'h00) ? 4'd1 :
                (char_10 == 8'h00) ? 4'd2 :
                (char_11 == 8'h00) ? 4'd3 :
                (char_12 == 8'h00) ? 4'd4 :
                (char_13 == 8'h00) ? 4'd5 :
                (char_14 == 8'h00) ? 4'd6 :
                (char_15 == 8'h00) ? 4'd7 : 4'd8;

  // Word 2 length calculation
  assign len2 = (char_16 == 8'h00) ? 4'd0 :
                (char_17 == 8'h00) ? 4'd1 :
                (char_18 == 8'h00) ? 4'd2 :
                (char_19 == 8'h00) ? 4'd3 :
                (char_20 == 8'h00) ? 4'd4 :
                (char_21 == 8'h00) ? 4'd5 :
                (char_22 == 8'h00) ? 4'd6 :
                (char_23 == 8'h00) ? 4'd7 : 4'd8;

  // Word 3 length calculation
  assign len3 = (char_24 == 8'h00) ? 4'd0 :
                (char_25 == 8'h00) ? 4'd1 :
                (char_26 == 8'h00) ? 4'd2 :
                (char_27 == 8'h00) ? 4'd3 :
                (char_28 == 8'h00) ? 4'd4 :
                (char_29 == 8'h00) ? 4'd5 :
                (char_30 == 8'h00) ? 4'd6 :
                (char_31 == 8'h00) ? 4'd7 : 4'd8;

  // Word 4 length calculation
  assign len4 = (char_32 == 8'h00) ? 4'd0 :
                (char_33 == 8'h00) ? 4'd1 :
                (char_34 == 8'h00) ? 4'd2 :
                (char_35 == 8'h00) ? 4'd3 :
                (char_36 == 8'h00) ? 4'd4 :
                (char_37 == 8'h00) ? 4'd5 :
                (char_38 == 8'h00) ? 4'd6 :
                (char_39 == 8'h00) ? 4'd7 : 4'd8;

  // Word 5 length calculation
  assign len5 = (char_40 == 8'h00) ? 4'd0 :
                (char_41 == 8'h00) ? 4'd1 :
                (char_42 == 8'h00) ? 4'd2 :
                (char_43 == 8'h00) ? 4'd3 :
                (char_44 == 8'h00) ? 4'd4 :
                (char_45 == 8'h00) ? 4'd5 :
                (char_46 == 8'h00) ? 4'd6 :
                (char_47 == 8'h00) ? 4'd7 : 4'd8;

  // Word 6 length calculation
  assign len6 = (char_48 == 8'h00) ? 4'd0 :
                (char_49 == 8'h00) ? 4'd1 :
                (char_50 == 8'h00) ? 4'd2 :
                (char_51 == 8'h00) ? 4'd3 :
                (char_52 == 8'h00) ? 4'd4 :
                (char_53 == 8'h00) ? 4'd5 :
                (char_54 == 8'h00) ? 4'd6 :
                (char_55 == 8'h00) ? 4'd7 : 4'd8;

  // Word 7 length calculation
  assign len7 = (char_56 == 8'h00) ? 4'd0 :
                (char_57 == 8'h00) ? 4'd1 :
                (char_58 == 8'h00) ? 4'd2 :
                (char_59 == 8'h00) ? 4'd3 :
                (char_60 == 8'h00) ? 4'd4 :
                (char_61 == 8'h00) ? 4'd5 :
                (char_62 == 8'h00) ? 4'd6 :
                (char_63 == 8'h00) ? 4'd7 : 4'd8;

  // Find maximum length
  assign max_length = (len0 > len1) ? (len0 > len2) ? (len0 > len3) ? (len0 > len4) ? (len0 > len5) ? (len0 > len6) ? (len0 > len7) ? len0 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len4 > len5) ? (len4 > len6) ? (len4 > len7) ? len4 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len3 > len4) ? (len3 > len5) ? (len3 > len6) ? (len3 > len7) ? len3 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len4 > len5) ? (len4 > len6) ? (len4 > len7) ? len4 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len2 > len3) ? (len2 > len4) ? (len2 > len5) ? (len2 > len6) ? (len2 > len7) ? len2 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len4 > len5) ? (len4 > len6) ? (len4 > len7) ? len4 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len3 > len4) ? (len3 > len5) ? (len3 > len6) ? (len3 > len7) ? len3 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len4 > len5) ? (len4 > len6) ? (len4 > len7) ? len4 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len1 > len2) ? (len1 > len3) ? (len1 > len4) ? (len1 > len5) ? (len1 > len6) ? (len1 > len7) ? len1 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len4 > len5) ? (len4 > len6) ? (len4 > len7) ? len4 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len3 > len4) ? (len3 > len5) ? (len3 > len6) ? (len3 > len7) ? len3 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len4 > len5) ? (len4 > len6) ? (len4 > len7) ? len4 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len2 > len3) ? (len2 > len4) ? (len2 > len5) ? (len2 > len6) ? (len2 > len7) ? len2 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len4 > len5) ? (len4 > len6) ? (len4 > len7) ? len4 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len3 > len4) ? (len3 > len5) ? (len3 > len6) ? (len3 > len7) ? len3 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7 : (len4 > len5) ? (len4 > len6) ? (len4 > len7) ? len4 : len7 : (len6 > len7) ? len6 : len7 : (len5 > len6) ? (len5 > len7) ? len5 : len7 : (len6 > len7) ? len6 : len7;

endmodule