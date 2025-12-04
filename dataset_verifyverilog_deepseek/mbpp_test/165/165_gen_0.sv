module char_position_counter(input [7:0] str [0:7], output [3:0] count);
  wire [7:0] matches;
  assign matches[0] = (str[0] == 8'd65 || str[0] == 8'd97);
  assign matches[1] = (str[1] == 8'd66 || str[1] == 8'd98);
  assign matches[2] = (str[2] == 8'd67 || str[2] == 8'd99);
  assign matches[3] = (str[3] == 8'd68 || str[3] == 8'd100);
  assign matches[4] = (str[4] == 8'd69 || str[4] == 8'd101);
  assign matches[5] = (str[5] == 8'd70 || str[5] == 8'd102);
  assign matches[6] = (str[6] == 8'd71 || str[6] == 8'd103);
  assign matches[7] = (str[7] == 8'd72 || str[7] == 8'd104);
  assign count = matches[0] + matches[1] + matches[2] + matches[3] + matches[4] + matches[5] + matches[6] + matches[7];
endmodule