module string_encrypt(
  input  [127:0] data_in,
  input  [3:0]   length,
  output [127:0] data_out
);

  reg [127:0] data_out_reg;
  assign data_out = data_out_reg;

  integer i;
  reg [7:0] char_val;

  always @* begin
    data_out_reg = data_in;
    for (i = 0; i < 16; i = i + 1) begin
      if (i < length) begin
        char_val = data_in[127 - 8*i -: 8];
        data_out_reg[127 - 8*i -: 8] = char_val + 8'd4;
      end
    end
  end

endmodule