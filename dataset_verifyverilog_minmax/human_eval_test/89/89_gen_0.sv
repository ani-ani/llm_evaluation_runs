module string_encrypt (
  input reg [127:0] data_in,
  input reg [3:0] length,
  output reg [127:0] data_out
);

  integer i;
  always @* begin
    data_out = data_in;
    for (i = 0; i < 16; i = i + 1) begin
      if (i < length) begin
        data_out[i*8 +: 8] = data_in[i*8 +: 8] + 8'd4;
      end
    end
  end

endmodule