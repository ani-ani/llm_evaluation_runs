module decimal_to_binary_converter(
  input  wire [15:0] decimal_in,
  output reg  [15:0] binary_out,
  output reg  [4:0]  significant_bits
);

  // Explicit pass-through of the binary representation
  always_comb binary_out = decimal_in;

  // Priority-encoded MSB detection to compute the number of significant bits (1..16)
  // For 0, return 1 (as required)
  always_comb begin
    integer i;
    int msb_pos;
    if (decimal_in == 16'b0) begin
      significant_bits = 5'b00001; // 1
    end else begin
      msb_pos = -1;
      for (i = 15; i >= 0; i = i - 1) begin
        if (decimal_in[i]) begin
          msb_pos = i;
          break;
        end
      end
      // msb_pos is guaranteed >= 0 here because decimal_in != 0
      significant_bits = 5'(msb_pos + 1);
    end
  end

endmodule