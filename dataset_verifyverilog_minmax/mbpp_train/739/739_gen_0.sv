module triangular_index (
  input [2:0] n_digits,
  output reg [7:0] index
);

  // Integer square root (ceil) for values up to 200000
  function [8:0] isqrt_ceil;
    input [31:0] x;
    integer i;
    begin
      isqrt_ceil = 0;
      for (i = 0; i < 65536; i = i + 1) begin
        if ((i * i) <= x) isqrt_ceil = i;
      end
      // If i^2 <= x, then the next integer (i+1) is the ceil(sqrt(x))
      if ((isqrt_ceil * isqrt_ceil) < x) isqrt_ceil = isqrt_ceil + 1;
    end
  endfunction

  always @* begin
    case (n_digits)
      3'd1: index = isqrt_ceil(2 * 1);       // 2 -> 2
      3'd2: index = isqrt_ceil(2 * 10);      // 20 -> 4
      3'd3: index = isqrt_ceil(2 * 100);     // 200 -> 14
      3'd4: index = isqrt_ceil(2 * 1000);    // 2000 -> 45
      3'd5: index = isqrt_ceil(2 * 10000);   // 20000 -> 142
      3'd6: index = isqrt_ceil(2 * 100000);  // 200000 -> 447
      default: index = 8'b0;
    endcase
  end

endmodule
