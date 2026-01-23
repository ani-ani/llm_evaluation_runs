module toy_shop (
  input [31:0] n,
  input [31:0] k,
  output reg [31:0] count
);

  reg [31:0] min_a;
  reg [31:0] max_a;
  reg [31:0] temp;

  always @* begin
    // Compute min_a = max(1, k - n)
    temp = k - n;
    min_a = (temp > 1) ? temp : 1;

    // Compute max_a = floor((k - 1) / 2)
    max_a = (k - 1) >> 1;

    // Check if min_a > max_a or edge cases
    if ((k <= 2) || (k > (2 * n - 1)) || (min_a > max_a)) begin
      count = 0;
    end else begin
      count = max_a - min_a + 1;
    end
  end

endmodule