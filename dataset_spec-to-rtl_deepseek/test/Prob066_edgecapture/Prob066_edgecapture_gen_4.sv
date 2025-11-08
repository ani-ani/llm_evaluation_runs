module TopModule(input clk, input reset, input [31:0] in, output reg [31:0] out);
  reg [31:0] prev_in;
  wire [31:0] fall_edge = prev_in & ~in;

  always_ff @(posedge clk) begin
    if (reset) begin
      prev_in <= 32'b0;
      out <= 32'b0;
    end else begin
      prev_in <= in;
      out <= out | fall_edge;
    end
  end
endmodule