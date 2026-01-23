module extract_even (
  input [3:0] level1_0,
  input [3:0] level1_1,
  input [3:0] level1_2,
  input [3:0] level1_3,
  input [3:0] level2_0,
  input [3:0] level2_1,
  input [3:0] level2_2,
  input [3:0] level2_3,
  output [3:0] result_0,
  output [3:0] result_1,
  output [3:0] result_2,
  output [3:0] result_3,
  output [2:0] valid_count
);

  wire [3:0] filtered_level1_0 = (level1_0[0] == 1'b0) ? level1_0 : 4'b0;
  wire [3:0] filtered_level1_1 = (level1_1[0] == 1'b0) ? level1_1 : 4'b0;
  wire [3:0] filtered_level1_2 = (level1_2[0] == 1'b0) ? level1_2 : 4'b0;
  wire [3:0] filtered_level1_3 = (level1_3[0] == 1'b0) ? level1_3 : 4'b0;
  wire [3:0] filtered_level2_0 = (level2_0[0] == 1'b0) ? level2_0 : 4'b0;
  wire [3:0] filtered_level2_1 = (level2_1[0] == 1'b0) ? level2_1 : 4'b0;
  wire [3:0] filtered_level2_2 = (level2_2[0] == 1'b0) ? level2_2 : 4'b0;
  wire [3:0] filtered_level2_3 = (level2_3[0] == 1'b0) ? level2_3 : 4'b0;

  wire [3:0] filtered_elements [0:7] = '{filtered_level1_0, filtered_level1_1, filtered_level1_2, filtered_level1_3, filtered_level2_0, filtered_level2_1, filtered_level2_2, filtered_level2_3};

  wire [3:0] non_zero_elements [0:7];
  integer i, j;
  for (i = 0; i < 8; i = i + 1) begin
    non_zero_elements[i] = (filtered_elements[i] != 4'b0) ? filtered_elements[i] : 4'b0;
  end

  wire [3:0] sorted_elements [0:7];
  for (i = 0; i < 8; i = i + 1) begin
    for (j = i + 1; j < 8; j = j + 1) begin
      if (non_zero_elements[i] == 4'b0 && non_zero_elements[j] != 4'b0) begin
        sorted_elements[i] = non_zero_elements[j];
        sorted_elements[j] = non_zero_elements[i];
      end else begin
        sorted_elements[i] = non_zero_elements[i];
        sorted_elements[j] = non_zero_elements[j];
      end
    end
  end

  assign result_0 = sorted_elements[0];
  assign result_1 = sorted_elements[1];
  assign result_2 = sorted_elements[2];
  assign result_3 = sorted_elements[3];

  wire [2:0] count = 0;
  for (i = 0; i < 4; i = i + 1) begin
    if (sorted_elements[i] != 4'b0) begin
      count = count + 1;
    end
  end
  assign valid_count = count;

endmodule