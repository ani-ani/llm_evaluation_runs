module list_increment (input [7:0][7:0] l, output reg [7:0][7:0] result);
  always @* begin
    for (int i = 0; i < 8; i = i + 1) begin
      result[i] = l[i] + 1'b1;
    end
  end
endmodule