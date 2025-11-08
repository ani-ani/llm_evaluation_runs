module TopModule(
  input  wire clk,
  input  wire in,
  output logic out
);
  always_ff @(posedge clk) begin
    out <= in ^ out;
  end
endmodule