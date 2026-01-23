module string_xor(input [15:0] a, input [15:0] b, input [3:0] len, output [15:0] result);
  reg [15:0] mask;
  always @(*) begin
    case(len)
      0: mask = 16'd0;
      1: mask = 16'd1;
      2: mask = 16'd3;
      3: mask = 16'd7;
      4: mask = 16'd15;
      5: mask = 16'd31;
      6: mask = 16'd63;
      7: mask = 16'd127;
      8: mask = 16'd255;
      9: mask = 16'd511;
      10: mask = 16'd1023;
      11: mask = 16'd2047;
      12: mask = 16'd4095;
      13: mask = 16'd8191;
      14: mask = 16'd16383;
      15: mask = 16'd32767;
    endcase
  end
  assign result = (a ^ b) & mask;
endmodule