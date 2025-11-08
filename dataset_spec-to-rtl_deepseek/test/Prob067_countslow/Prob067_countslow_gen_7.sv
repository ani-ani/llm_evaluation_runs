module TopModule (input clk, input reset, input slowena, output logic [3:0] q);
  logic [3:0] counter;
  
  always_ff @(posedge clk) begin
    if (reset)
      counter <= 4'd0;
    else if (slowena)
      counter <= (counter == 4'd9) ? 4'd0 : counter + 4'd1;
  end
  
  assign q = counter;
endmodule