module pair_sum_counter (
  input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
  input [8:0] target_sum,
  input valid,
  output reg [3:0] pair_count,
  output reg result_valid
);

  reg [8:0] sum_01, sum_02, sum_03, sum_04, sum_05, sum_06, sum_07;
  reg [8:0] sum_12, sum_13, sum_14, sum_15, sum_16, sum_17;
  reg [8:0] sum_23, sum_24, sum_25, sum_26, sum_27;
  reg [8:0] sum_34, sum_35, sum_36, sum_37;
  reg [8:0] sum_45, sum_46, sum_47;
  reg [8:0] sum_56, sum_57;
  reg [8:0] sum_67;

  // Compute all possible sums
  assign sum_01 = $signed(arr_0) + $signed(arr_1);
  assign sum_02 = $signed(arr_0) + $signed(arr_2);
  assign sum_03 = $signed(arr_0) + $signed(arr_3);
  assign sum_04 = $signed(arr_0) + $signed(arr_4);
  assign sum_05 = $signed(arr_0) + $signed(arr_5);
  assign sum_06 = $signed(arr_0) + $signed(arr_6);
  assign sum_07 = $signed(arr_0) + $signed(arr_7);

  assign sum_12 = $signed(arr_1) + $signed(arr_2);
  assign sum_13 = $signed(arr_1) + $signed(arr_3);
  assign sum_14 = $signed(arr_1) + $signed(arr_4);
  assign sum_15 = $signed(arr_1) + $signed(arr_5);
  assign sum_16 = $signed(arr_1) + $signed(arr_6);
  assign sum_17 = $signed(arr_1) + $signed(arr_7);

  assign sum_23 = $signed(arr_2) + $signed(arr_3);
  assign sum_24 = $signed(arr_2) + $signed(arr_4);
  assign sum_25 = $signed(arr_2) + $signed(arr_5);
  assign sum_26 = $signed(arr_2) + $signed(arr_6);
  assign sum_27 = $signed(arr_2) + $signed(arr_7);

  assign sum_34 = $signed(arr_3) + $signed(arr_4);
  assign sum_35 = $signed(arr_3) + $signed(arr_5);
  assign sum_36 = $signed(arr_3) + $signed(arr_6);
  assign sum_37 = $signed(arr_3) + $signed(arr_7);

  assign sum_45 = $signed(arr_4) + $signed(arr_5);
  assign sum_46 = $signed(arr_4) + $signed(arr_6);
  assign sum_47 = $signed(arr_4) + $signed(arr_7);

  assign sum_56 = $signed(arr_5) + $signed(arr_6);
  assign sum_57 = $signed(arr_5) + $signed(arr_7);

  assign sum_67 = $signed(arr_6) + $signed(arr_7);

  // Compare each sum to target and count matches
  always @(*) begin
    pair_count = 0;
    result_valid = valid;

    if (sum_01 == target_sum) pair_count = pair_count + 1;
    if (sum_02 == target_sum) pair_count = pair_count + 1;
    if (sum_03 == target_sum) pair_count = pair_count + 1;
    if (sum_04 == target_sum) pair_count = pair_count + 1;
    if (sum_05 == target_sum) pair_count = pair_count + 1;
    if (sum_06 == target_sum) pair_count = pair_count + 1;
    if (sum_07 == target_sum) pair_count = pair_count + 1;

    if (sum_12 == target_sum) pair_count = pair_count + 1;
    if (sum_13 == target_sum) pair_count = pair_count + 1;
    if (sum_14 == target_sum) pair_count = pair_count + 1;
    if (sum_15 == target_sum) pair_count = pair_count + 1;
    if (sum_16 == target_sum) pair_count = pair_count + 1;
    if (sum_17 == target_sum) pair_count = pair_count + 1;

    if (sum_23 == target_sum) pair_count = pair_count + 1;
    if (sum_24 == target_sum) pair_count = pair_count + 1;
    if (sum_25 == target_sum) pair_count = pair_count + 1;
    if (sum_26 == target_sum) pair_count = pair_count + 1;
    if (sum_27 == target_sum) pair_count = pair_count + 1;

    if (sum_34 == target_sum) pair_count = pair_count + 1;
    if (sum_35 == target_sum) pair_count = pair_count + 1;
    if (sum_36 == target_sum) pair_count = pair_count + 1;
    if (sum_37 == target_sum) pair_count = pair_count + 1;

    if (sum_45 == target_sum) pair_count = pair_count + 1;
    if (sum_46 == target_sum) pair_count = pair_count + 1;
    if (sum_47 == target_sum) pair_count = pair_count + 1;

    if (sum_56 == target_sum) pair_count = pair_count + 1;
    if (sum_57 == target_sum) pair_count = pair_count + 1;

    if (sum_67 == target_sum) pair_count = pair_count + 1;
  end

endmodule