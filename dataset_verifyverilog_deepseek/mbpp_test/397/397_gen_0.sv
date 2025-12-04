module median_of_three (input reg [7:0] a, b, c, output reg [7:0] median);
  always @(*) begin
    if (a > b) begin
      if (a < c) begin
        median = a;
      end else if (b > c) begin
        median = b;
      end else begin
        median = c;
      end
    end else begin
      if (a > c) begin
        median = a;
      end else if (b < c) begin
        median = b;
      end else begin
        median = c;
      end
    end
  end
endmodule