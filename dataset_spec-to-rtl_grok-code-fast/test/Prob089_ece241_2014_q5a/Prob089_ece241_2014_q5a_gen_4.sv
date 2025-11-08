module TopModule (
  input clk,
  input areset,
  input x,
  output z
);

  reg carry;

  assign z = areset ? 1'b0 : (~x ^ carry);

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      carry <= 1'b1;
    end else begin
      carry <= (~x & carry);
    end
  end

endmodule