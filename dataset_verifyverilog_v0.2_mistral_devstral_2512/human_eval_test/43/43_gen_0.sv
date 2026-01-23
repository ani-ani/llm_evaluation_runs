module pairs_sum_to_zero (
  input [7:0] elements_0,
  input [7:0] elements_1,
  input [7:0] elements_2,
  input [7:0] elements_3,
  input [7:0] elements_4,
  input [7:0] elements_5,
  input [7:0] elements_6,
  input [7:0] elements_7,
  input [2:0] valid_count,
  output result
);

  wire [7:0] elements [0:7];
  assign elements[0] = elements_0;
  assign elements[1] = elements_1;
  assign elements[2] = elements_2;
  assign elements[3] = elements_3;
  assign elements[4] = elements_4;
  assign elements[5] = elements_5;
  assign elements[6] = elements_6;
  assign elements[7] = elements_7;

  wire [7:0] sum_01, sum_02, sum_03, sum_04, sum_05, sum_06, sum_07;
  wire [7:0] sum_12, sum_13, sum_14, sum_15, sum_16, sum_17;
  wire [7:0] sum_23, sum_24, sum_25, sum_26, sum_27;
  wire [7:0] sum_34, sum_35, sum_36, sum_37;
  wire [7:0] sum_45, sum_46, sum_47;
  wire [7:0] sum_56, sum_57;
  wire [7:0] sum_67;

  assign sum_01 = elements[0] + elements[1];
  assign sum_02 = elements[0] + elements[2];
  assign sum_03 = elements[0] + elements[3];
  assign sum_04 = elements[0] + elements[4];
  assign sum_05 = elements[0] + elements[5];
  assign sum_06 = elements[0] + elements[6];
  assign sum_07 = elements[0] + elements[7];

  assign sum_12 = elements[1] + elements[2];
  assign sum_13 = elements[1] + elements[3];
  assign sum_14 = elements[1] + elements[4];
  assign sum_15 = elements[1] + elements[5];
  assign sum_16 = elements[1] + elements[6];
  assign sum_17 = elements[1] + elements[7];

  assign sum_23 = elements[2] + elements[3];
  assign sum_24 = elements[2] + elements[4];
  assign sum_25 = elements[2] + elements[5];
  assign sum_26 = elements[2] + elements[6];
  assign sum_27 = elements[2] + elements[7];

  assign sum_34 = elements[3] + elements[4];
  assign sum_35 = elements[3] + elements[5];
  assign sum_36 = elements[3] + elements[6];
  assign sum_37 = elements[3] + elements[7];

  assign sum_45 = elements[4] + elements[5];
  assign sum_46 = elements[4] + elements[6];
  assign sum_47 = elements[4] + elements[7];

  assign sum_56 = elements[5] + elements[6];
  assign sum_57 = elements[5] + elements[7];

  assign sum_67 = elements[6] + elements[7];

  wire check_01, check_02, check_03, check_04, check_05, check_06, check_07;
  wire check_12, check_13, check_14, check_15, check_16, check_17;
  wire check_23, check_24, check_25, check_26, check_27;
  wire check_34, check_35, check_36, check_37;
  wire check_45, check_46, check_47;
  wire check_56, check_57;
  wire check_67;

  assign check_01 = (valid_count > 1) && (sum_01 == 8'b0);
  assign check_02 = (valid_count > 2) && (sum_02 == 8'b0);
  assign check_03 = (valid_count > 3) && (sum_03 == 8'b0);
  assign check_04 = (valid_count > 4) && (sum_04 == 8'b0);
  assign check_05 = (valid_count > 5) && (sum_05 == 8'b0);
  assign check_06 = (valid_count > 6) && (sum_06 == 8'b0);
  assign check_07 = (valid_count > 7) && (sum_07 == 8'b0);

  assign check_12 = (valid_count > 2) && (sum_12 == 8'b0);
  assign check_13 = (valid_count > 3) && (sum_13 == 8'b0);
  assign check_14 = (valid_count > 4) && (sum_14 == 8'b0);
  assign check_15 = (valid_count > 5) && (sum_15 == 8'b0);
  assign check_16 = (valid_count > 6) && (sum_16 == 8'b0);
  assign check_17 = (valid_count > 7) && (sum_17 == 8'b0);

  assign check_23 = (valid_count > 3) && (sum_23 == 8'b0);
  assign check_24 = (valid_count > 4) && (sum_24 == 8'b0);
  assign check_25 = (valid_count > 5) && (sum_25 == 8'b0);
  assign check_26 = (valid_count > 6) && (sum_26 == 8'b0);
  assign check_27 = (valid_count > 7) && (sum_27 == 8'b0);

  assign check_34 = (valid_count > 4) && (sum_34 == 8'b0);
  assign check_35 = (valid_count > 5) && (sum_35 == 8'b0);
  assign check_36 = (valid_count > 6) && (sum_36 == 8'b0);
  assign check_37 = (valid_count > 7) && (sum_37 == 8'b0);

  assign check_45 = (valid_count > 5) && (sum_45 == 8'b0);
  assign check_46 = (valid_count > 6) && (sum_46 == 8'b0);
  assign check_47 = (valid_count > 7) && (sum_47 == 8'b0);

  assign check_56 = (valid_count > 6) && (sum_56 == 8'b0);
  assign check_57 = (valid_count > 7) && (sum_57 == 8'b0);

  assign check_67 = (valid_count > 7) && (sum_67 == 8'b0);

  assign result = check_01 || check_02 || check_03 || check_04 || check_05 || check_06 || check_07 ||
                 check_12 || check_13 || check_14 || check_15 || check_16 || check_17 ||
                 check_23 || check_24 || check_25 || check_26 || check_27 ||
                 check_34 || check_35 || check_36 || check_37 ||
                 check_45 || check_46 || check_47 ||
                 check_56 || check_57 ||
                 check_67;

endmodule