module list_to_dict(
  input reg [3:0][31:0] key1,
  input reg [3:0][127:0] key2,
  input reg [3:0][15:0] value,
  output reg [3:0][31:0] key1_out,
  output reg [3:0][127:0] key2_out,
  output reg [3:0][15:0] value_out
);

  always_comb begin
    key1_out = key1;
    key2_out = key2;
    value_out = value;
  end

endmodule