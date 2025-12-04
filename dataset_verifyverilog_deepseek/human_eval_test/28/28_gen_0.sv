module string_concat (
  input [3:0] valid_mask,
  input [3:0][31:0] strings,
  output [127:0] concatenated
);
  
  wire [1:0] count0 = 1'd0;
  wire [1:0] count1 = valid_mask[0];
  wire [1:0] count2 = count1 + valid_mask[1];
  wire [1:0] count3 = count2 + valid_mask[2];
  
  wire [127:0] conn0 = valid_mask[0] ? ({96'd0, strings[0]} << (count0 * 32)) : 128'd0;
  wire [127:0] conn1 = valid_mask[1] ? ({96'd0, strings[1]} << (count1 * 32)) : 128'd0;
  wire [127:0] conn2 = valid_mask[2] ? ({96'd0, strings[2]} << (count2 * 32)) : 128'd0;
  wire [127:0] conn3 = valid_mask[3] ? ({96'd0, strings[3]} << (count3 * 32)) : 128'd0;
  
  assign concatenated = conn0 | conn1 | conn2 | conn3;
  
endmodule