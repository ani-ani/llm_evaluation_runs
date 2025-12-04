module max_element(input signed [7:0] values [0:7], output signed [7:0] max_value);
  wire signed [7:0] stage1 [0:3];
  wire signed [7:0] stage2 [0:1];

  assign stage1[0] = (values[0] > values[1]) ? values[0] : values[1];
  assign stage1[1] = (values[2] > values[3]) ? values[2] : values[3];
  assign stage1[2] = (values[4] > values[5]) ? values[4] : values[5];
  assign stage1[3] = (values[6] > values[7]) ? values[6] : values[7];

  assign stage2[0] = (stage1[0] > stage1[1]) ? stage1[0] : stage1[1];
  assign stage2[1] = (stage1[2] > stage1[3]) ? stage1[2] : stage1[3];

  assign max_value = (stage2[0] > stage2[1]) ? stage2[0] : stage2[1];
endmodule