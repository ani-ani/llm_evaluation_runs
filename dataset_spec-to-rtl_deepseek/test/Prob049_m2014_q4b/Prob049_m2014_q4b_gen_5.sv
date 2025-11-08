module TopModule(input clk, ar, d, output reg q);
  always_ff @(posedge clk or posedge ar) begin
    if (ar) q <= 1'b0;
    else q <= d;
  end
endmodule