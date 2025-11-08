module TopModule (
  input clk,
  input reset,
  output logic [3:0] q
);

  logic [3:0] count_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      count_reg <= 4'b0000;
    end else begin
      count_reg <= count_reg + 1;
    end
  end

  assign q = count_reg;

endmodule