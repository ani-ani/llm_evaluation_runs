module TopModule(input clk, input reset, input [31:0] in, output [31:0] out);
  reg [31:0] captured;
  reg [31:0] prev_in;

  always @(posedge clk) begin
    if (reset) begin
      prev_in <= 32'b0;
      captured <= 32'b0;
    end else begin
      integer i;
      for (i = 0; i < 32; i = i + 1) begin
        if (prev_in[i] && !in[i]) begin
          captured[i] <= 1'b1;
        end
      end
      prev_in <= in;
    end
  end

  assign out = captured;
endmodule