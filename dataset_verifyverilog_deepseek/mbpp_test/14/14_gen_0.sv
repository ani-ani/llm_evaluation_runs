module triangular_prism_volume(input [7:0] l, b, h, output [7:0] volume);
  assign volume = (l * b * h) >> 1;
endmodule