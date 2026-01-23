module total_match (
  input [7:0] list1_valid,
  input [7:0][7:0][7:0] list1_data,
  input [7:0][3:0] list1_lengths,
  input [7:0] list2_valid,
  input [7:0][7:0][7:0] list2_data,
  input [7:0][3:0] list2_lengths,
  output [7:0] result_list1_valid,
  output [7:0][7:0][7:0] result_list1_data,
  output [7:0][3:0] result_list1_lengths,
  output is_first_list
);

  // Compute total characters for list1
  wire [6:0] sum_list1;
  wire [6:0] sum_list1_stage1 = list1_valid[0] ? list1_lengths[0] : 0 +
                                list1_valid[1] ? list1_lengths[1] : 0 +
                                list1_valid[2] ? list1_lengths[2] : 0 +
                                list1_valid[3] ? list1_lengths[3] : 0;
  wire [6:0] sum_list1_stage2 = list1_valid[4] ? list1_lengths[4] : 0 +
                                list1_valid[5] ? list1_lengths[5] : 0 +
                                list1_valid[6] ? list1_lengths[6] : 0 +
                                list1_valid[7] ? list1_lengths[7] : 0;
  assign sum_list1 = sum_list1_stage1 + sum_list1_stage2;

  // Compute total characters for list2
  wire [6:0] sum_list2;
  wire [6:0] sum_list2_stage1 = list2_valid[0] ? list2_lengths[0] : 0 +
                                list2_valid[1] ? list2_lengths[1] : 0 +
                                list2_valid[2] ? list2_lengths[2] : 0 +
                                list2_valid[3] ? list2_lengths[3] : 0;
  wire [6:0] sum_list2_stage2 = list2_valid[4] ? list2_lengths[4] : 0 +
                                list2_valid[5] ? list2_lengths[5] : 0 +
                                list2_valid[6] ? list2_lengths[6] : 0 +
                                list2_valid[7] ? list2_lengths[7] : 0;
  assign sum_list2 = sum_list2_stage1 + sum_list2_stage2;

  // Determine which list to select
  assign is_first_list = (sum_list1 <= sum_list2);

  // Select the appropriate list data
  assign result_list1_valid = is_first_list ? list1_valid : list2_valid;

  // Select string data
  genvar i, j;
  generate
    for (i = 0; i < 8; i = i + 1) begin : string_loop
      for (j = 0; j < 8; j = j + 1) begin : char_loop
        assign result_list1_data[i][j] = is_first_list ? list1_data[i][j] : list2_data[i][j];
      end
    end
  endgenerate

  // Select string lengths
  genvar k;
  generate
    for (k = 0; k < 8; k = k + 1) begin : length_loop
      assign result_list1_lengths[k] = is_first_list ? list1_lengths[k] : list2_lengths[k];
    end
  endgenerate

endmodule