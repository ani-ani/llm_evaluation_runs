module TopModule(
  input  clk,
  input  reset,
  output shift_ena
);
  logic [2:0] count_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      count_reg <= 3'b000;
    end else if (count_reg < 3'b100) begin
      count_reg <= count_reg + 1;
    end
  end

  assign shift_ena = (count_reg < 3'b100);
endmodule