module odd_digit_product(input [15:0] num, output reg [12:0] product);
  wire [3:0] d4 = num / 16'd10000;
  wire [3:0] d3 = (num % 16'd10000) / 16'd1000;
  wire [3:0] d2 = (num % 16'd1000) / 16'd100;
  wire [3:0] d1 = (num % 16'd100) / 16'd10;
  wire [3:0] d0 = num % 16'd10;
  wire is_odd4 = d4[0];
  wire is_odd3 = d3[0];
  wire is_odd2 = d2[0];
  wire is_odd1 = d1[0];
  wire is_odd0 = d0[0];
  wire [3:0] m4 = is_odd4 ? d4 : 4'd1;
  wire [3:0] m3 = is_odd3 ? d3 : 4'd1;
  wire [3:0] m2 = is_odd2 ? d2 : 4'd1;
  wire [3:0] m1 = is_odd1 ? d1 : 4'd1;
  wire [3:0] m0 = is_odd0 ? d0 : 4'd1;
  wire [16:0] product_full = m4 * m3 * m2 * m1 * m0;
  wire any_odd = is_odd4 | is_odd3 | is_odd2 | is_odd1 | is_odd0;
  always @(*) begin
    if (any_odd)
      product = product_full[12:0];
    else
      product = 13'd0;
  end
endmodule