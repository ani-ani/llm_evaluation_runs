module rolling_max (
  input [2:0] size,
  input [63:0] numbers,
  output reg [63:0] result
);

  wire [7:0] elem0 = numbers[7:0];
  wire [7:0] elem1 = numbers[15:8];
  wire [7:0] elem2 = numbers[23:16];
  wire [7:0] elem3 = numbers[31:24];
  wire [7:0] elem4 = numbers[39:32];
  wire [7:0] elem5 = numbers[47:40];
  wire [7:0] elem6 = numbers[55:48];
  wire [7:0] elem7 = numbers[63:56];

  wire [7:0] max0 = elem0;
  wire [7:0] max1 = (max0 > elem1) ? max0 : elem1;
  wire [7:0] max2 = (max1 > elem2) ? max1 : elem2;
  wire [7:0] max3 = (max2 > elem3) ? max2 : elem3;
  wire [7:0] max4 = (max3 > elem4) ? max3 : elem4;
  wire [7:0] max5 = (max4 > elem5) ? max4 : elem5;
  wire [7:0] max6 = (max5 > elem6) ? max5 : elem6;
  wire [7:0] max7 = (max6 > elem7) ? max6 : elem7;

  always @* begin
    result[7:0]   = max0;
    result[15:8]  = (size > 3'd1) ? max1 : 8'bx;
    result[23:16] = (size > 3'd2) ? max2 : 8'bx;
    result[31:24] = (size > 3'd3) ? max3 : 8'bx;
    result[39:32] = (size > 3'd4) ? max4 : 8'bx;
    result[47:40] = (size > 3'd5) ? max5 : 8'bx;
    result[55:48] = (size > 3'd6) ? max6 : 8'bx;
    result[63:56] = (size > 3'd7) ? max7 : 8'bx;
  end

endmodule