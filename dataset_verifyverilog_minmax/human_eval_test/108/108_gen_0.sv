module count_positive_digit_sums(
  input [7:0] arr [0:7],
  output reg [3:0] count
);
  integer i;
  always @(*) begin
    count = 0;
    for (i = 0; i < 8; i = i + 1) begin
      // Treat arr[i] as signed 8-bit by casting with sign extension
      logic signed [7:0] val;
      val = $signed({1'b0, arr[i]});
      if (val < 0) begin
        // Negative: take first signed digit as negative, rest positive
        // Use absolute value to avoid sign on 2's complement wrap-around
        logic [7:0] mag;
        mag = (~val) + 1;
        // Extract digits: d1 (most significant), then d2, d3
        logic [3:0] d1, d2, d3;
        d1 = mag / 100;    // 0..1 for 0..127 (but val<0 => 1..1 for 128 only)
        d2 = (mag / 10) % 10;
        d3 = mag % 10;
        if (d1 > 0) begin
          if ((-d1 + d2 + d3) > 0) count = count + 1;
        end else begin
          if ((d2 + d3) > 0) count = count + 1;
        end
      end else begin
        // Positive/zero: all digits positive
        logic [7:0] mag;
        mag = val;
        logic [3:0] d1, d2, d3;
        d1 = mag / 100;    // 0..1
        d2 = (mag / 10) % 10;
        d3 = mag % 10;
        if (d1 > 0) begin
          if ((d1 + d2 + d3) > 0) count = count + 1;
        end else begin
          if ((d2 + d3) > 0) count = count + 1;
        end
      end
    end
  end
endmodule
