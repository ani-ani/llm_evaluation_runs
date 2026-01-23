module element_counter (
  input [7:0] target,
  input [11:0][7:0] data_array,
  output [7:0] count
);

  wire [11:0] matches;
  genvar i;
  generate
    for (i = 0; i < 12; i = i + 1) begin : match_gen
      assign matches[i] = (data_array[i] == target) ? 1'b1 : 1'b0;
    end
  endgenerate

  wire [3:0] sum1_0 = matches[0] + matches[1] + matches[2] + matches[3];
  wire [3:0] sum1_1 = matches[4] + matches[5] + matches[6] + matches[7];
  wire [3:0] sum1_2 = matches[8] + matches[9] + matches[10] + matches[11];

  wire [4:0] sum2_0 = sum1_0 + sum1_1;
  wire [4:0] sum2_1 = sum1_2 + 4'b0;

  wire [4:0] sum3 = sum2_0 + sum2_1;

  assign count = sum3;

endmodule