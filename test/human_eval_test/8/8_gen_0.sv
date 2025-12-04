module sum_product(
  input  [3:0]  len,
  input  [63:0] numbers,
  output [15:0] sum,
  output [63:0] product
);

  wire [7:0] e0 = numbers[63:56];
  wire [7:0] e1 = numbers[55:48];
  wire [7:0] e2 = numbers[47:40];
  wire [7:0] e3 = numbers[39:32];
  wire [7:0] e4 = numbers[31:24];
  wire [7:0] e5 = numbers[23:16];
  wire [7:0] e6 = numbers[15:8];
  wire [7:0] e7 = numbers[7:0];

  reg [15:0] sum_r;
  reg [63:0] prod_r;

  always @* begin
    // Default for len=0
    sum_r  = 16'd0;
    prod_r = 64'd1;

    if (len > 0) begin
      sum_r  = sum_r  + e0;
      prod_r = prod_r * e0;
    end
    if (len > 1) begin
      sum_r  = sum_r  + e1;
      prod_r = prod_r * e1;
    end
    if (len > 2) begin
      sum_r  = sum_r  + e2;
      prod_r = prod_r * e2;
    end
    if (len > 3) begin
      sum_r  = sum_r  + e3;
      prod_r = prod_r * e3;
    end
    if (len > 4) begin
      sum_r  = sum_r  + e4;
      prod_r = prod_r * e4;
    end
    if (len > 5) begin
      sum_r  = sum_r  + e5;
      prod_r = prod_r * e5;
    end
    if (len > 6) begin
      sum_r  = sum_r  + e6;
      prod_r = prod_r * e6;
    end
    if (len > 7) begin
      sum_r  = sum_r  + e7;
      prod_r = prod_r * e7;
    end
  end

  assign sum     = sum_r;
  assign product = prod_r;

endmodule