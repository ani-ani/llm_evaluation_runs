module TopModule(input clk, input [7:0] in, output logic [7:0] anyedge);
  logic [7:0] prev_in;
  
  always_ff @(posedge clk) begin
    prev_in <= in;
  end
  
  assign anyedge = prev_in ^ in;
endmodule