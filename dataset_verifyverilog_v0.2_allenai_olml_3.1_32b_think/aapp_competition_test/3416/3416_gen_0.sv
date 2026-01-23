module traveling_salesman(output [1:0] min_flights, output [3:0] airports);
input [3:0] n, m;
input [5:0] edges [0:5];

assign min_flights = 2'b00;
assign airports = 4'b0000;
endmodule