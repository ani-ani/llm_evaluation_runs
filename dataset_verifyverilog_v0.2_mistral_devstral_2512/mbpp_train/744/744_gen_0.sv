module check_none (
  input [3:0] data_0,
  input [3:0] data_1,
  input [3:0] data_2,
  input [3:0] data_3,
  input [3:0] data_4,
  output has_none
);

  assign has_none = (data_0 == 4'b1111) ||
                    (data_1 == 4'b1111) ||
                    (data_2 == 4'b1111) ||
                    (data_3 == 4'b1111) ||
                    (data_4 == 4'b1111);

endmodule