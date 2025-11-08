module TopModule(input clk, a, b, output q, output state);
  reg current_state;
  
  // Update state on positive clock edge
  always_ff @(posedge clk) begin
    current_state <= current_state ^ (a == b);
  end
  
  // Output assignments
  assign state = current_state;
  assign q = current_state ? ~(a ^ b) : (a ^ b);
endmodule