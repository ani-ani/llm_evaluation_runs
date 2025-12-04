module crashing_line_cost(
  input  [3:0]  n,
  input  [31:0] r,
  input  [31:0] p,
  output reg [31:0] cost
);

  // Internal array to hold T(1) through T(16)
  reg [31:0] T [1:16];

  integer i, k;
  reg [31:0] best_cost;
  reg [31:0] k_cost;
  reg [4:0]  denom;        // k+1 fits in 5 bits (max 16)
  reg [4:0]  ceil_seg;     // ceil(n/(k+1)) max 16
  reg [8:0]  tmp_mul;      // n * 32 fits in 9 bits

  always @* begin
    // Base case
    T[1] = 32'd0;

    // Bottom-up computation for T[2]..T[16]
    for (i = 2; i <= 16; i = i + 1) begin
      best_cost = 32'hFFFFFFFF; // large initial value

      // Try all k from 1 to i-1
      for (k = 1; k <= i-1; k = k + 1) begin
        denom = k + 1;

        // ceil(i / (k+1)) using integer arithmetic: (i + denom - 1) / denom
        tmp_mul = i + denom - 1;
        ceil_seg = tmp_mul / denom;

        // cost_k = p*k + r + T(ceil_seg)
        k_cost = (p * k) + r + T[ceil_seg];

        if (k_cost < best_cost)
          best_cost = k_cost;
      end

      T[i] = best_cost;
    end

    // Select cost based on input n (1..16)
    if (n >= 4'd1 && n <= 4'd16)
      cost = T[n];
    else if (n == 4'd0)
      cost = 32'd0; // undefined by spec; map 0 to 0 cost
    else
      cost = T[16]; // saturate for n > 16 (not expected by spec)
  end

endmodule