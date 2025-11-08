module TopModule(input clk, reset, data, output reg start_shifting);
  reg [3:0] sr;
  always_ff @(posedge clk) begin
    if (reset) begin
      sr <= 4'b0000;
      start_shifting <= 1'b0;
    end else begin
      reg [3:0] new_sr = {sr[2:0], data};
      sr <= new_sr;
      if (new_sr == 4'b1101) start_shifting <= 1'b1;
    end
  end
endmodule