module sum_of_squares(
    input reg [7:0] n,
    output reg [24:0] sum_squares
  );

    reg [31:0] a, b, c;

    always @(*) begin
      a = 2 * n;
      b = a * (n+1);
      c = b * (2*n+1);
      sum_squares = c / 3;
    end

  endmodule