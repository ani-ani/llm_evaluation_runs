module count_element(
  input  [63:0] array_data,
  input  [3:0]  target,
  output [3:0]  count
);

  wire [3:0] e0  = array_data[3:0];
  wire [3:0] e1  = array_data[7:4];
  wire [3:0] e2  = array_data[11:8];
  wire [3:0] e3  = array_data[15:12];
  wire [3:0] e4  = array_data[19:16];
  wire [3:0] e5  = array_data[23:20];
  wire [3:0] e6  = array_data[27:24];
  wire [3:0] e7  = array_data[31:28];
  wire [3:0] e8  = array_data[35:32];
  wire [3:0] e9  = array_data[39:36];
  wire [3:0] e10 = array_data[43:40];
  wire [3:0] e11 = array_data[47:44];

  wire [3:0] m0  = (e0  == target) ? 4'd1 : 4'd0;
  wire [3:0] m1  = (e1  == target) ? 4'd1 : 4'd0;
  wire [3:0] m2  = (e2  == target) ? 4'd1 : 4'd0;
  wire [3:0] m3  = (e3  == target) ? 4'd1 : 4'd0;
  wire [3:0] m4  = (e4  == target) ? 4'd1 : 4'd0;
  wire [3:0] m5  = (e5  == target) ? 4'd1 : 4'd0;
  wire [3:0] m6  = (e6  == target) ? 4'd1 : 4'd0;
  wire [3:0] m7  = (e7  == target) ? 4'd1 : 4'd0;
  wire [3:0] m8  = (e8  == target) ? 4'd1 : 4'd0;
  wire [3:0] m9  = (e9  == target) ? 4'd1 : 4'd0;
  wire [3:0] m10 = (e10 == target) ? 4'd1 : 4'd0;
  wire [3:0] m11 = (e11 == target) ? 4'd1 : 4'd0;

  wire [3:0] s0  = m0  + m1;
  wire [3:0] s1  = m2  + m3;
  wire [3:0] s2  = m4  + m5;
  wire [3:0] s3  = m6  + m7;
  wire [3:0] s4  = m8  + m9;
  wire [3:0] s5  = m10 + m11;

  wire [3:0] s6  = s0 + s1;
  wire [3:0] s7  = s2 + s3;
  wire [3:0] s8  = s4 + s5;

  wire [3:0] s9  = s6 + s7;

  assign count = s9 + s8; // max 12, fits in 4 bits

endmodule