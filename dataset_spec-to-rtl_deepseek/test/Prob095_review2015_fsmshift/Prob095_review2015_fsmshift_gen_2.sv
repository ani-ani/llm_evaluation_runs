module TopModule(input clk, input reset, output shift_ena);
  reg [1:0] count;
  reg done;

  always @(posedge clk) begin
    if (reset) begin
      count <= 2'b00;
      done <= 1'b0;
    end else if (!done) begin
      if (count == 2'b11) done <= 1'b1;
      else count <= count + 1;
    end
  end

  assign shift_ena = !done && !reset;
endmodule