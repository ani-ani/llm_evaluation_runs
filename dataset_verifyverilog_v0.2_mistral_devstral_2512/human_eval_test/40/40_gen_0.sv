module triples_sum_to_zero (
  input [3:0] num0,
  input [3:0] num1,
  input [3:0] num2,
  input [3:0] num3,
  input [3:0] num4,
  input [3:0] num5,
  input [3:0] num6,
  input [3:0] num7,
  input [2:0] count,
  output result
);

  wire [4:0] sum012 = $signed(num0) + $signed(num1) + $signed(num2);
  wire [4:0] sum013 = $signed(num0) + $signed(num1) + $signed(num3);
  wire [4:0] sum014 = $signed(num0) + $signed(num1) + $signed(num4);
  wire [4:0] sum015 = $signed(num0) + $signed(num1) + $signed(num5);
  wire [4:0] sum016 = $signed(num0) + $signed(num1) + $signed(num6);
  wire [4:0] sum017 = $signed(num0) + $signed(num1) + $signed(num7);
  wire [4:0] sum023 = $signed(num0) + $signed(num2) + $signed(num3);
  wire [4:0] sum024 = $signed(num0) + $signed(num2) + $signed(num4);
  wire [4:0] sum025 = $signed(num0) + $signed(num2) + $signed(num5);
  wire [4:0] sum026 = $signed(num0) + $signed(num2) + $signed(num6);
  wire [4:0] sum027 = $signed(num0) + $signed(num2) + $signed(num7);
  wire [4:0] sum034 = $signed(num0) + $signed(num3) + $signed(num4);
  wire [4:0] sum035 = $signed(num0) + $signed(num3) + $signed(num5);
  wire [4:0] sum036 = $signed(num0) + $signed(num3) + $signed(num6);
  wire [4:0] sum037 = $signed(num0) + $signed(num3) + $signed(num7);
  wire [4:0] sum045 = $signed(num0) + $signed(num4) + $signed(num5);
  wire [4:0] sum046 = $signed(num0) + $signed(num4) + $signed(num6);
  wire [4:0] sum047 = $signed(num0) + $signed(num4) + $signed(num7);
  wire [4:0] sum056 = $signed(num0) + $signed(num5) + $signed(num6);
  wire [4:0] sum057 = $signed(num0) + $signed(num5) + $signed(num7);
  wire [4:0] sum067 = $signed(num0) + $signed(num6) + $signed(num7);
  wire [4:0] sum123 = $signed(num1) + $signed(num2) + $signed(num3);
  wire [4:0] sum124 = $signed(num1) + $signed(num2) + $signed(num4);
  wire [4:0] sum125 = $signed(num1) + $signed(num2) + $signed(num5);
  wire [4:0] sum126 = $signed(num1) + $signed(num2) + $signed(num6);
  wire [4:0] sum127 = $signed(num1) + $signed(num2) + $signed(num7);
  wire [4:0] sum134 = $signed(num1) + $signed(num3) + $signed(num4);
  wire [4:0] sum135 = $signed(num1) + $signed(num3) + $signed(num5);
  wire [4:0] sum136 = $signed(num1) + $signed(num3) + $signed(num6);
  wire [4:0] sum137 = $signed(num1) + $signed(num3) + $signed(num7);
  wire [4:0] sum145 = $signed(num1) + $signed(num4) + $signed(num5);
  wire [4:0] sum146 = $signed(num1) + $signed(num4) + $signed(num6);
  wire [4:0] sum147 = $signed(num1) + $signed(num4) + $signed(num7);
  wire [4:0] sum156 = $signed(num1) + $signed(num5) + $signed(num6);
  wire [4:0] sum157 = $signed(num1) + $signed(num5) + $signed(num7);
  wire [4:0] sum167 = $signed(num1) + $signed(num6) + $signed(num7);
  wire [4:0] sum234 = $signed(num2) + $signed(num3) + $signed(num4);
  wire [4:0] sum235 = $signed(num2) + $signed(num3) + $signed(num5);
  wire [4:0] sum236 = $signed(num2) + $signed(num3) + $signed(num6);
  wire [4:0] sum237 = $signed(num2) + $signed(num3) + $signed(num7);
  wire [4:0] sum245 = $signed(num2) + $signed(num4) + $signed(num5);
  wire [4:0] sum246 = $signed(num2) + $signed(num4) + $signed(num6);
  wire [4:0] sum247 = $signed(num2) + $signed(num4) + $signed(num7);
  wire [4:0] sum256 = $signed(num2) + $signed(num5) + $signed(num6);
  wire [4:0] sum257 = $signed(num2) + $signed(num5) + $signed(num7);
  wire [4:0] sum267 = $signed(num2) + $signed(num6) + $signed(num7);
  wire [4:0] sum345 = $signed(num3) + $signed(num4) + $signed(num5);
  wire [4:0] sum346 = $signed(num3) + $signed(num4) + $signed(num6);
  wire [4:0] sum347 = $signed(num3) + $signed(num4) + $signed(num7);
  wire [4:0] sum356 = $signed(num3) + $signed(num5) + $signed(num6);
  wire [4:0] sum357 = $signed(num3) + $signed(num5) + $signed(num7);
  wire [4:0] sum367 = $signed(num3) + $signed(num6) + $signed(num7);
  wire [4:0] sum456 = $signed(num4) + $signed(num5) + $signed(num6);
  wire [4:0] sum457 = $signed(num4) + $signed(num5) + $signed(num7);
  wire [4:0] sum467 = $signed(num4) + $signed(num6) + $signed(num7);
  wire [4:0] sum567 = $signed(num5) + $signed(num6) + $signed(num7);

  wire any_triplet_zero = 
    (count >= 3) && (
      (sum012 == 0) || (sum013 == 0) || (sum014 == 0) || (sum015 == 0) || (sum016 == 0) || (sum017 == 0) ||
      (sum023 == 0) || (sum024 == 0) || (sum025 == 0) || (sum026 == 0) || (sum027 == 0) || (sum034 == 0) ||
      (sum035 == 0) || (sum036 == 0) || (sum037 == 0) || (sum045 == 0) || (sum046 == 0) || (sum047 == 0) ||
      (sum056 == 0) || (sum057 == 0) || (sum067 == 0) || (sum123 == 0) || (sum124 == 0) || (sum125 == 0) ||
      (sum126 == 0) || (sum127 == 0) || (sum134 == 0) || (sum135 == 0) || (sum136 == 0) || (sum137 == 0) ||
      (sum145 == 0) || (sum146 == 0) || (sum147 == 0) || (sum156 == 0) || (sum157 == 0) || (sum167 == 0) ||
      (sum234 == 0) || (sum235 == 0) || (sum236 == 0) || (sum237 == 0) || (sum245 == 0) || (sum246 == 0) ||
      (sum247 == 0) || (sum256 == 0) || (sum257 == 0) || (sum267 == 0) || (sum345 == 0) || (sum346 == 0) ||
      (sum347 == 0) || (sum356 == 0) || (sum357 == 0) || (sum367 == 0) || (sum456 == 0) || (sum457 == 0) ||
      (sum467 == 0) || (sum567 == 0)
    );

  assign result = any_triplet_zero;

endmodule