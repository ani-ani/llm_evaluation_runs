module toggle_middle_bits (input reg [7:0] n, output reg [7:0] result);
  always_comb begin
    if (n == 8'd0 || n == 8'd1) begin
      result = n;
    end else begin
      logic [7:0] set_mask;
      set_mask = n | (n >> 1) | (n >> 2) | (n >> 3) | (n >> 4) | (n >> 5) | (n >> 6) | (n >> 7);
      logic [7:0] mask = (set_mask >> 1) ^ 8'h01;
      result = n ^ mask;
    end
  end
endmodule