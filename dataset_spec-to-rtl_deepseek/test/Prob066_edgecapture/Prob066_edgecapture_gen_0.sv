module TopModule(
  input  wire        clk,
  input  wire        reset,
  input  wire [31:0] in,
  output reg  [31:0] out
);

  reg [31:0] prev_in;
  reg [31:0] detected;

  always @(posedge clk) begin
    if (reset) begin
      prev_in  <= 32'b0;
      detected <= 32'b0;
    end else begin
      detected <= detected | (prev_in & ~in);
      prev_in  <= in;
    end
  end

  always_comb begin
    out = detected;
  end

endmodule