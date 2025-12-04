module odd_length_sum(input reg [7:0] arr_0, arr_1, arr_2, arr_3, output reg [7:0] sum);
wire [11:0] total;
assign total = (12'd2 * arr_0) + (12'd3 * arr_1) + (12'd3 * arr_2) + (12'd2 * arr_3);
always @(*) begin
  sum = total[7:0];
end
endmodule