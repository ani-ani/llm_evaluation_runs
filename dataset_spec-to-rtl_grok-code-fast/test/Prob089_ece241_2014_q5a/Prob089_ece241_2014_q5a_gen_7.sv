module TopModule (
  input clk,
  input areset,
  input x,
  output z
);

  reg carry;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      carry <= 1'b1;
    end else begin
      carry <= ~x & carry;
    end
  end

  assign z = x ^ carry;

endmodule