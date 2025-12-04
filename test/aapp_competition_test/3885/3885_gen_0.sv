module min_cost_tickets(
  input  [15:0] n,
  output [14:0] min_cost
);

  assign min_cost = (n - 16'd1) >> 1;

endmodule