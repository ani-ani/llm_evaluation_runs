module TopModule(input clk, input reset, output logic [9:0] q);
  always_ff @(posedge clk) begin
    if (reset) q <= 10'd0;
    else if (q == 10'd999) q <= 10'd0;
    else q <= q + 1'b1;
  end
endmodule