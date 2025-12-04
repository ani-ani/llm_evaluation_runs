module prod_signs (input [2:0] array_length, input signed [7:0] arr [0:7], output signed [11:0] result, output valid);
  wire valid = (array_length != 3'b0);
  wire [7:0] active;
  wire [10:0] abs_extended [0:7];
  wire [7:0] zero_detect;
  wire [7:0] neg_active;
  wire [10:0] sum_raw;
  wire any_zero;
  wire [2:0] neg_count;
  wire [11:0] sum_12bit;
  wire signed [11:0] pos_result, neg_result;
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : ACTIVE_GEN
      assign active[i] = (i < array_length);
    end
  endgenerate
  generate
    for (i = 0; i < 8; i = i + 1) begin : ABS_GEN
      wire [7:0] abs_val = active[i] ? (arr[i][7] ? -arr[i] : arr[i]) : 8'b0;
      assign abs_extended[i] = {3'b0, abs_val};
    end
  endgenerate
  assign sum_raw = abs_extended[0] + abs_extended[1] + abs_extended[2] + abs_extended[3] +
                  abs_extended[4] + abs_extended[5] + abs_extended[6] + abs_extended[7];
  generate
    for (i = 0; i < 8; i = i + 1) begin : ZERO_DETECT_GEN
      assign zero_detect[i] = active[i] && (arr[i] == 8'sb0);
    end
  endgenerate
  assign any_zero = |zero_detect;
  generate
    for (i = 0; i < 8; i = i + 1) begin : NEG_ACTIVE_GEN
      assign neg_active[i] = active[i] && (arr[i] < 0);
    end
  endgenerate
  assign neg_count = neg_active[0] + neg_active[1] + neg_active[2] + neg_active[3] +
                    neg_active[4] + neg_active[5] + neg_active[6] + neg_active[7];
  assign sum_12bit = {1'b0, sum_raw};
  assign pos_result = $signed(sum_12bit);
  assign neg_result = -pos_result;
  assign result = any_zero ? 12'sb0 : 
                  (neg_count[0] ? neg_result : pos_result);
endmodule