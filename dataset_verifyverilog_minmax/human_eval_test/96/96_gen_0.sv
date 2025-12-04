module example (input wire clk, input wire reset, output reg [7:0] counter);

  always @(posedge clk or posedge reset) begin
    if (reset)
      counter <= 8'h00;
    else
      counter <= counter + 1;
    end
endmodule