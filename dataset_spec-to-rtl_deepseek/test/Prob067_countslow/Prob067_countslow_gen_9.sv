module TopModule(input clk, input reset, input slowena, output logic [3:0] q);
  always_ff @(posedge clk) begin
    if (reset) q <= 4'b0;
    else if (slowena) begin
      if (q == 4'd9) q <= 4'b0;
      else q <= q + 1;
    end
  end
endmodule