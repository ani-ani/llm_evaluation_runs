module product_even_checker #(
  parameter N = 8,
  parameter WIDTH = 8
)(
  input [N-1:0][WIDTH-1:0] numbers,
  input [2:0] valid_count,
  output reg is_even
);

  wire [N-1:0] lsbs;
  wire [N-1:0] inverted_lsbs;
  wire any_even;

  // Extract LSB from each number
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : extract_lsb
      assign lsbs[i] = numbers[i][0];
    end
  endgenerate

  // Invert LSBs (0 becomes 1, 1 becomes 0)
  genvar j;
  generate
    for (j = 0; j < N; j = j + 1) begin : invert_lsb
      assign inverted_lsbs[j] = ~lsbs[j];
    end
  endgenerate

  // Reduction OR on inverted LSBs of valid numbers
  assign any_even = |inverted_lsbs[valid_count-1:0];

  // Final result
  always @(*) begin
    is_even = any_even;
  end

endmodule