module min_blocked_points(
  input [15:0] n,
  output [19:0] result
);

  wire [33:0] product = n * 18'd92682;
  wire [17:0] truncated = product[33:16];
  assign result = (n == 16'd0) ? 20'd1 : {truncated, 2'b00};

endmodule