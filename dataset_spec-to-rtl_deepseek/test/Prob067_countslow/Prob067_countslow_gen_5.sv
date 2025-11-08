module TopModule(input clk, input reset, input slowena, output logic [3:0] q);
  always_ff @(posedge clk) begin
    if (reset)
      q <= 4'b0;
    else if (slowena)
      q <= (q == 4'd9) ? 4'b0 : q + 1'b1;
  end
endmodule