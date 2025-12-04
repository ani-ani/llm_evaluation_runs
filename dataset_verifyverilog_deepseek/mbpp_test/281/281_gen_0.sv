module unique_checker(input [3:0] data[0:3], output reg is_unique);
  wire [5:0] eq_all;
  assign eq_all = {data[0] == data[1], data[0] == data[2], data[0] == data[3],
                  data[1] == data[2], data[1] == data[3], data[2] == data[3]};
  always @* begin
    is_unique = ~|eq_all;
  end
endmodule