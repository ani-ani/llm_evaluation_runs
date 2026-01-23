module toy_shop(input [31:0] n, input [31:0] k, output reg [31:0] count);
  always @(*) begin
    reg [31:0] temp, min_a, max_a;
    temp = n + 1;
    min_a = (k >= temp) ? (k - n) : 1;
    max_a = (k - 1) >> 1;
    if (min_a > max_a)
      count = 0;
    else
      count = max_a - min_a + 1;
  end
endmodule