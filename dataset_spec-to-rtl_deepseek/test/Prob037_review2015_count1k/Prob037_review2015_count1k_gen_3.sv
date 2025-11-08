module TopModule(input clk, input reset, output [9:0] q);
  reg [9:0] count_reg;
  
  assign q = count_reg;
  
  always_ff @(posedge clk) begin
    if (reset) begin
      count_reg <= 10'd0;
    end else begin
      if (count_reg == 10'd999) begin
        count_reg <= 10'd0;
      end else begin
        count_reg <= count_reg + 1'b1;
      end
    end
  end
endmodule