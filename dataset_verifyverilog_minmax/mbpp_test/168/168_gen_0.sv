module frequency_counter (
  input [7:0] x,
  input [7:0] list_array [7:0],
  output reg [3:0] count
);

logic [7:0] eq_bits;

genvar i;
generate
for (i = 0; i < 8; i = i + 1) begin : cmp
  assign eq_bits[i] = (x == list_array[i]);
end
endgenerate

assign count = eq_bits[0] + eq_bits[1] + eq_bits[2] + eq_bits[3] +
               eq_bits[4] + eq_bits[5] + eq_bits[6] + eq_bits[7];

endmodule