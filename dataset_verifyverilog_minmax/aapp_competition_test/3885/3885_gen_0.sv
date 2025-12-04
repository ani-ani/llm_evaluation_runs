module min_cost_tickets(
  input logic [15:0] n,
  output logic [14:0] min_cost
);
  assign min_cost = (n - 1) >> 1;
endmodule