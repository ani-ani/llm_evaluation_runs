module upper_case_counter(
  input  [63:0] str_bytes,
  output [3:0]  count
);

  wire [7:0] c0 = str_bytes[63:56];
  wire [7:0] c1 = str_bytes[55:48];
  wire [7:0] c2 = str_bytes[47:40];
  wire [7:0] c3 = str_bytes[39:32];
  wire [7:0] c4 = str_bytes[31:24];
  wire [7:0] c5 = str_bytes[23:16];
  wire [7:0] c6 = str_bytes[15:8];
  wire [7:0] c7 = str_bytes[7:0];

  wire u0 = (c0 >= 8'd65) && (c0 <= 8'd90);
  wire u1 = (c1 >= 8'd65) && (c1 <= 8'd90);
  wire u2 = (c2 >= 8'd65) && (c2 <= 8'd90);
  wire u3 = (c3 >= 8'd65) && (c3 <= 8'd90);
  wire u4 = (c4 >= 8'd65) && (c4 <= 8'd90);
  wire u5 = (c5 >= 8'd65) && (c5 <= 8'd90);
  wire u6 = (c6 >= 8'd65) && (c6 <= 8'd90);
  wire u7 = (c7 >= 8'd65) && (c7 <= 8'd90);

  wire [3:0] sum01 = u0 + u1;
  wire [3:0] sum23 = u2 + u3;
  wire [3:0] sum45 = u4 + u5;
  wire [3:0] sum67 = u6 + u7;

  assign count = sum01 + sum23 + sum45 + sum67;

endmodule