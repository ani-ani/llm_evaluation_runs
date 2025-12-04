module string_splitter (
  input [7:0][7:0] packed_string,
  input [2:0] len,
  output reg [7:0] char0, char1, char2, char3, char4, char5, char6, char7,
  output reg [7:0] valid_mask
);

  always_comb begin
    {char0, char1, char2, char3, char4, char5, char6, char7} = packed_string;
    valid_mask = (8'd1 << len) - 8'd1;
  end

endmodule