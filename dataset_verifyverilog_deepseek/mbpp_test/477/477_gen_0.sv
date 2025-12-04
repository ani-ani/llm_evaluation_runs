module string_to_lower (
  input [63:0] string_in,
  output reg [63:0] string_out
);
  always_comb begin
    for (int i=0; i<8; i++) begin
      if ((string_in[8*i +: 8] >= 8'd65) && (string_in[8*i +: 8] <= 8'd90))
        string_out[8*i +: 8] = string_in[8*i +: 8] + 8'd32;
      else
        string_out[8*i +: 8] = string_in[8*i +: 8];
    end
  end
endmodule