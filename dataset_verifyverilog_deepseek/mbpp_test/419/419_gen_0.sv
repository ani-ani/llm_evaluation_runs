module round_and_sum (
  input [15:0] numbers[0:7],
  input [2:0] length,
  output logic [13:0] total
);

  always_comb begin
    logic [9:0] sum = 10'h0;
    for (int i = 0; i < 8; i++) begin
      if (i < length) begin
        logic signed [15:0] num_signed = $signed(numbers[i]);
        logic signed [15:0] added = num_signed + 16'sh0080;
        logic signed [15:0] rounded = added >>> 8;
        logic signed [7:0] rounded_8bit = rounded[7:0];
        logic [7:0] abs_val = (rounded_8bit < 0) ? -rounded_8bit : rounded_8bit;
        sum = sum + abs_val;
      end
    end
    total = sum * length;
  end

endmodule