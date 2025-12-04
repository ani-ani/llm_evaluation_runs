module tuple_concat (
  input [23:0] elem1,
  input [23:0] elem2,
  input [23:0] elem3,
  input [23:0] elem4,
  output [119:0] result
);
  assign result = {
    elem1[23:16], elem1[15:8], elem1[7:0], 8'h2D,
    elem2[23:16], elem2[15:8], elem2[7:0], 8'h2D,
    elem3[23:16], elem3[15:8], elem3[7:0], 8'h2D,
    elem4[23:16], elem4[15:8], elem4[7:0]
  };
endmodule