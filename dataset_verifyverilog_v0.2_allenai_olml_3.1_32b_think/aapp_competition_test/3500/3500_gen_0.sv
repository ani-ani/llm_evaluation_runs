module bingo_tie_check (
    input [6:0] card1_row0, card1_row1, card1_row2, card1_row3, card1_row4, card1_row5, card1_row6, card1_row7,
    input [6:0] card2_row0, card2_row1, card2_row2, card2_row3, card2_row4, card2_row5, card2_row6, card2_row7,
    output tie_possible,
    output [2:0] tie_row1, tie_row2,
    output [6:0] last_number
);

// Declare all match signals
wire match_00;
wire match_01;
wire match_02;
wire match_03;
wire match_04;
wire match_05;
wire match_06;
wire match_07;
wire match_10;
wire match_11;
wire match_12;
wire match_13;
wire match_14;
wire match_15;
wire match_16;
wire match_17;
wire match_20;
wire match_21;
wire match_22;
wire match_23;
wire match_24;
wire match_25;
wire match_26;
wire match_27;
wire match_30;
wire match_31;
wire match_32;
wire match_33;
wire match_34;
wire match_35;
wire match_36;
wire match_37;
wire match_40;
wire match_41;
wire match_42;
wire match_43;
wire match_44;
wire match_45;
wire match_46;
wire match_47;
wire match_50;
wire match_51;
wire match_52;
wire match_53;
wire match_54;
wire match_55;
wire match_56;
wire match_57;
wire match_60;
wire match_61;
wire match_62;
wire match_63;
wire match_64;
wire match_65;
wire match_66;
wire match_67;
wire match_70;
wire match_71;
wire match_72;
wire match_73;
wire match_74;
wire match_75;
wire match_76;
wire match_77;

// Compute all match_ij
assign match_00 = (card1_row0 == card2_row0);
assign match_01 = (card1_row0 == card2_row1);
assign match_02 = (card1_row0 == card2_row2);
assign match_03 = (card1_row0 == card2_row3);
assign match_04 = (card1_row0 == card2_row4);
assign match_05 = (card1_row0 == card2_row5);
assign match_06 = (card1_row0 == card2_row6);
assign match_07 = (card1_row0 == card2_row7);
assign match_10 = (card1_row1 == card2_row0);
assign match_11 = (card1_row1 == card2_row1);
assign match_12 = (card1_row1 == card2_row2);
assign match_13 = (card1_row1 == card2_row3);
assign match_14 = (card1_row1 == card2_row4);
assign match_15 = (card1_row1 == card2_row5);
assign match_16 = (card1_row1 == card2_row6);
assign match_17 = (card1_row1 == card2_row7);
assign match_20 = (card1_row2 == card2_row0);
assign match_21 = (card1_row2 == card2_row1);
assign match_22 = (card1_row2 == card2_row2);
assign match_23 = (card1_row2 == card2_row3);
assign match_24 = (card1_row2 == card2_row4);
assign match_25 = (card1_row2 == card2_row5);
assign match_26 = (card1_row2 == card2_row6);
assign match_27 = (card1_row2 == card2_row7);
assign match_30 = (card1_row3 == card2_row0);
assign match_31 = (card1_row3 == card2_row1);
assign match_32 = (card1_row3 == card2_row2);
assign match_33 = (card1_row3 == card2_row3);
assign match_34 = (card1_row3 == card2_row4);
assign match_35 = (card1_row3 == card2_row5);
assign match_36 = (card1_row3 == card2_row6);
assign match_37 = (card1_row3 == card2_row7);
assign match_40 = (card1_row4 == card2_row0);
assign match_41 = (card1_row4 == card2_row1);
assign match_42 = (card1_row4 == card2_row2);
assign match_43 = (card1_row4 == card2_row3);
assign match_44 = (card1_row4 == card2_row4);
assign match_45 = (card1_row4 == card2_row5);
assign match_46 = (card1_row4 == card2_row6);
assign match_47 = (card1_row4 == card2_row7);
assign match_50 = (card1_row5 == card2_row0);
assign match_51 = (card1_row5 == card2_row1);
assign match_52 = (card1_row5 == card2_row2);
assign match_53 = (card1_row5 == card2_row3);
assign match_54 = (card1_row5 == card2_row4);
assign match_55 = (card1_row5 == card2_row5);
assign match_56 = (card1_row5 == card2_row6);
assign match_57 = (card1_row5 == card2_row7);
assign match_60 = (card1_row6 == card2_row0);
assign match_61 = (card1_row6 == card2_row1);
assign match_62 = (card1_row6 == card2_row2);
assign match_63 = (card1_row6 == card2_row3);
assign match_64 = (card1_row6 == card2_row4);
assign match_65 = (card1_row6 == card2_row5);
assign match_66 = (card1_row6 == card2_row6);
assign match_67 = (card1_row6 == card2_row7);
assign match_70 = (card1_row7 == card2_row0);
assign match_71 = (card1_row7 == card2_row1);
assign match_72 = (card1_row7 == card2_row2);
assign match_73 = (card1_row7 == card2_row3);
assign match_74 = (card1_row7 == card2_row4);
assign match_75 = (card1_row7 == card2_row5);
assign match_76 = (card1_row7 == card2_row6);
assign match_77 = (card1_row7 == card2_row7);

// Compute any_match_i
wire [7:0] any_match_i;
assign any_match_i[0] = match_00 | match_01 | match_02 | match_03 | match_04 | match_05 | match_06 | match_07;
assign any_match_i[1] = match_10 | match_11 | match_12 | match_13 | match_14 | match_15 | match_16 | match_17;
assign any_match_i[2] = match_20 | match_21 | match_22 | match_23 | match_24 | match_25 | match_26 | match_27;
assign any_match_i[3] = match_30 | match_31 | match_32 | match_33 | match_34 | match_35 | match_36 | match_37;
assign any_match_i[4] = match_40 | match_41 | match_42 | match_43 | match_44 | match_45 | match_46 | match_47;
assign any_match_i[5] = match_50 | match_51 | match_52 | match_53 | match_54 | match_55 | match_56 | match_57;
assign any_match_i[6] = match_60 | match_61 | match_62 | match_63 | match_64 | match_65 | match_66 | match_67;
assign any_match_i[7] = match_70 | match_71 | match_72 | match_73 | match_74 | match_75 | match_76 | match_77;

// Compute i_first
wire [2:0] i_first;
assign i_first = any_match_i[0] ? 3'b000 : any_match_i[1] ? 3'b001 : any_match_i[2] ? 3'b010 : any_match_i[3] ? 3'b011 : any_match_i[4] ? 3'b100 : any_match_i[5] ? 3'b101 : any_match_i[6] ? 3'b110 : any_match_i[7] ? 3'b111 : 3'b000;

// Compute selected_card1
wire [6:0] selected_card1;
assign selected_card1 = i_first == 3'b000 ? card1_row0 : i_first == 3'b001 ? card1_row1 : i_first == 3'b010 ? card1_row2 : i_first == 3'b011 ? card1_row3 : i_first == 3'b100 ? card1_row4 : i_first == 3'b101 ? card1_row5 : i_first == 3'b110 ? card1_row6 : i_first == 3'b111 ? card1_row7 : card1_row0;

// Compute match_i_j_selected
wire [7:0] match_0_j;
assign match_0_j = {match_00, match_01, match_02, match_03, match_04, match_05, match_06, match_07};
wire [7:0] match_1_j;
assign match_1_j = {match_10, match_11, match_12, match_13, match_14, match_15, match_16, match_17};
wire [7:0] match_2_j;
assign match_2_j = {match_20, match_21, match_22, match_23, match_24, match_25, match_26, match_27};
wire [7:0] match_3_j;
assign match_3_j = {match_30, match_31, match_32, match_33, match_34, match_35, match_36, match_37};
wire [7:0] match_4_j;
assign match_4_j = {match_40, match_41, match_42, match_43, match_44, match_45, match_46, match_47};
wire [7:0] match_5_j;
assign match_5_j = {match_50, match_51, match_52, match_53, match_54, match_55, match_56, match_57};
wire [7:0] match_6_j;
assign match_6_j = {match_60, match_61, match_62, match_63, match_64, match_65, match_66, match_67};
wire [7:0] match_7_j;
assign match_7_j = {match_70, match_71, match_72, match_73, match_74, match_75, match_76, match_77};
wire [7:0] match_i_j_selected;
assign match_i_j_selected = i_first == 3'b000 ? match_0_j : i_first == 3'b001 ? match_1_j : i_first == 3'b010 ? match_2_j : i_first == 3'b011 ? match_3_j : i_first == 3'b100 ? match_4_j : i_first == 3'b101 ? match_5_j : i_first == 3'b110 ? match_6_j : i_first == 3'b111 ? match_7_j : 8'b0;

// Compute j_first
wire [2:0] j_first;
assign j_first = match_i_j_selected[0] ? 3'b000 : match_i_j_selected[1] ? 3'b001 : match_i_j_selected[2] ? 3'b010 : match_i_j_selected[3] ? 3'b011 : match_i_j_selected[4] ? 3'b100 : match_i_j_selected[5] ? 3'b101 : match_i_j_selected[6] ? 3'b110 : match_i_j_selected[7] ? 3'b111 : 3'b000;

// Compute tie_possible
wire tie_possible;
assign tie_possible = any_match_i[0] | any_match_i[1] | any_match_i[2] | any_match_i[3] | any_match_i[4] | any_match_i[5] | any_match_i[6] | any_match_i[7];

// Outputs
assign tie_row1 = tie_possible ? i_first : 3'b000;
assign tie_row2 = tie_possible ? j_first : 3'b000;
assign last_number = tie_possible ? selected_card1 : 7'd0;

endmodule