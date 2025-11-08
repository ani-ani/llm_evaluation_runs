module TopModule(input clk, input [7:0] in, output reg [7:0] pedge);

  reg [7:0] prev_in;

  initial begin
    prev_in = 8'b0;
    pedge = 8'b0;
  end

  always @(posedge clk) begin
    pedge <= (~prev_in & in);
    prev_in <= in;
  end

endmodule