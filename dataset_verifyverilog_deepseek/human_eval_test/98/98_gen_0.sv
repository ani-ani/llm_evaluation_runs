module count_upper(input [63:0] chars, output [2:0] count);
  wire [7:0] char0 = chars[63:56];
  wire [7:0] char2 = chars[47:40];
  wire [7:0] char4 = chars[31:24];
  wire [7:0] char6 = chars[15:8];
  
  wire match0 = (char0 == 8'd65) || (char0 == 8'd69) || (char0 == 8'd73) || (char0 == 8'd79) || (char0 == 8'd85);
  wire match2 = (char2 == 8'd65) || (char2 == 8'd69) || (char2 == 8'd73) || (char2 == 8'd79) || (char2 == 8'd85);
  wire match4 = (char4 == 8'd65) || (char4 == 8'd69) || (char4 == 8'd73) || (char4 == 8'd79) || (char4 == 8'd85);
  wire match6 = (char6 == 8'd65) || (char6 == 8'd69) || (char6 == 8'd73) || (char6 == 8'd79) || (char6 == 8'd85);
  
  assign count = match0 + match2 + match4 + match6;
endmodule