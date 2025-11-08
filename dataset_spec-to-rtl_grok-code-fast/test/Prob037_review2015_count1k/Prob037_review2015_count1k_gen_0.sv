module TopModule(
  input clk,
  input reset,
  output [9:0] q
);
  reg [9:0] counter;
  assign q = counter;

  always @(posedge clk) begin
    if (reset) begin
      counter <= 10'd0;
    end else begin
      if (counter == 10'd999) begin
        counter <= 10'd0;
      end else begin
        counter <= counter + 1;
      end
    end
  end
endmodule