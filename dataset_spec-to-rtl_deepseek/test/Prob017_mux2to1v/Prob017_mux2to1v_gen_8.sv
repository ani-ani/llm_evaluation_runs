module TopModule(
  input reg [99:0] a,
  input reg [99:0] b,
  input reg sel,
  output reg [99:0] out
);
  always @(*) begin
    if (sel == 1'b0) begin
      out = a;
    end else begin
      out = b;
    end
  end
endmodule