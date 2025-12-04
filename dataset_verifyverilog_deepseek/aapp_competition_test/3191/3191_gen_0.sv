module crashing_line_cost(input [3:0] n, input [31:0] r, input [31:0] p, output reg [31:0] cost);

  reg [31:0] T[1:16];

  always_comb begin
    T[1] = 0;
    for (int m = 2; m <= 16; m = m + 1) begin
      T[m] = {32{1'b1}};
      for (int k = 1; k <= m - 1; k = k + 1) begin
        int segment = (m + k) / (k + 1);
        reg [31:0] current_cost = p * k + r + T[segment];
        if (current_cost < T[m]) begin
          T[m] = current_cost;
        end
      end
    end
    cost = T[n];
  end

endmodule