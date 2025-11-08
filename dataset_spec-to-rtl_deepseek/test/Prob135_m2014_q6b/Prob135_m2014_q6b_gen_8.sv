module TopModule(
  input [2:0] y,
  input w,
  output Y1
);
  assign Y1 = w ? (y[0] ? ~y[1] : y[2] ^ y[1]) : (~y[1] & y[0]);
 tekrendmodule