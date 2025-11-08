module TopModule(input clk, input reset, output shift_ena);
  reg [1:0] count;
  reg done;
  
  always @(posedge clk) begin
    if (reset) begin
      count <= 2'b00;
      done <= 1'b0;
    end else if (!done) begin
      if (count == 2'b11) begin
        done <= 1'b1;
      end else begin
        count <= count + 1;
      end
    end
  end
  
  assign shift_ena = !done;
endmodule