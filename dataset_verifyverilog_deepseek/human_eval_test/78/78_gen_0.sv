module hex_prime_counter (
  input [4:0] len,
  input [127:0] hex_str,
  output logic [5:0] count
);

wire [31:0] prime_valid;

generate
  genvar i;
  for (i=0; i < 32; i=i+1) begin : gen_digit
    wire [3:0] digit = hex_str[127 - 4*i -: 4];
    wire is_prime = digit inside {4'h2, 4'h3, 4'h5, 4'h7, 4'hB, 4'hD};
    assign prime_valid[i] = (i < len) ? is_prime : 1'b0;
  end
endgenerate

always_comb begin
  count = 0;
  for (int j=0; j < 32; j++) begin
    count += prime_valid[j];
  end
end

endmodule