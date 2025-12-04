module top_n_prices(
  input [31:0] item_prices, // [3]=MSW..[0]=LSW, each Q16.16
  input [1:0] n, // 1..3
  output reg [95:0] top_prices // {price2, price1, price0}
);
  // unpack 4 prices from packed array item_prices[3..0]
  wire [31:0] p3 = item_prices[127:96];
  wire [31:0] p2 = item_prices[95:64];
  wire [31:0] p1 = item_prices[63:32];
  wire [31:0] p0 = item_prices[31:0];

  // 4-input sorting network to get descending order: s0 >= s1 >= s2 >= s3
  // All values are signed Q16.16
  wire [31:0] s0, s1, s2, s3;

  // Stage 1
  wire [31:0] m0a = (p0 >= p1) ? p0 : p1;
  wire [31:0] m0b = (p0 >= p1) ? p1 : p0;
  wire [31:0] m0c = (p2 >= p3) ? p2 : p3;
  wire [31:0] m0d = (p2 >= p3) ? p3 : p2;

  // Stage 2
  wire [31:0] m1a = (m0a >= m0c) ? m0a : m0c; // provisional max
  wire [31:0] m1b = (m0a >= m0c) ? m0c : m0a;
  wire [31:0] m1c = (m0b >= m0d) ? m0b : m0d; // provisional min
  wire [31:0] m1d = (m0b >= m0d) ? m0d : m0b;

  // Stage 3
  wire [31:0] m2a = (m1a >= m1b) ? m1a : m1b; // max
  wire [31:0] m2b = (m1a >= m1b) ? m1b : m1a;
  wire [31:0] m2c = (m1c >= m1d) ? m1c : m1d; // min
  wire [31:0] m2d = (m1c >= m1d) ? m1d : m1c;

  // Stage 4
  assign s0 = (m2b >= m2c) ? m2b : m2c;
  assign s1 = (m2b >= m2c) ? m2c : m2b;
  assign s2 = (m2d >= m2c) ? m2d : m2c;
  assign s3 = (m2d >= m2c) ? m2c : m2d;

  // Select top n values from sorted list and build output with zero padding
  wire [31:0] price0 = (n == 1) ? s0 : (n >= 2) ? s0 : 32'h0;
  wire [31:0] price1 = (n == 2) ? s1 : (n == 3) ? s1 : 32'h0;
  wire [31:0] price2 = (n == 3) ? s2 : 32'h0;

  always @(*) begin
    case (n)
      2'b01: top_prices = {32'h0, 32'h0, price0};
      2'b10: top_prices = {32'h0, price1, price0};
      2'b11: top_prices = {price2, price1, price0};
      default: top_prices = 96'h0; // default: n=0 or invalid
    endcase
  end
endmodule