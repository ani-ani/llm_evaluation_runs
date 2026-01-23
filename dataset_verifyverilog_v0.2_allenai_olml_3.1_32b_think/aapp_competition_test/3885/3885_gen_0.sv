module min_ticket_cost(input [16:0] n, output [15:0] cost);
assign cost = (n - 1) >> 1;
endmodule