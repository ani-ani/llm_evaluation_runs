module triangle_area(input reg [15:0] a, input reg [15:0] h, output reg [15:0] area);
  always_comb
    area = (a * h) >> 9;
endmodule