module TopModule(
  input clk,
  input reset,
  input [31:0] in,
  output [31:0] out
);

  reg [31:0] in_prev;
  reg [31:0] captured;

  always @(posedge clk) begin
    if (reset) begin
      in_prev <= 32'b0;
      captured <= 32'b0;
    end else begin
      in_prev <= in;
      captured <= captured | (in_prev & ~in);
    end
  end

  assign out = captured;

endmodule