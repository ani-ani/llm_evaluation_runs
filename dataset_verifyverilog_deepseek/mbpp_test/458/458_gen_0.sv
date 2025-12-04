module rectangle_area(input reg [7:0] l, input reg [7:0] b, output logic [15:0] area);
  assign area = l * b;
endmodule