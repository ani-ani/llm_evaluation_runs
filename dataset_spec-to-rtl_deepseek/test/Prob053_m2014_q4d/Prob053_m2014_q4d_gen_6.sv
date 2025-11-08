module TopModule(input clk, input in, output logic out);
  wire d_input;
  assign d_input = in ^ out;
  always_ff @(posedge clk) begin
    out <= d_input;
  end
endmodule