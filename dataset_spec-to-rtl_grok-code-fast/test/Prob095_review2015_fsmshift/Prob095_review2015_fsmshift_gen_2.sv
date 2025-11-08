module TopModule(input clk, input reset, output shift_ena);
  reg prev_reset;
  reg shifting;
  reg [1:0] counter;
  assign shift_ena = shifting;
  always @(posedge clk) begin
    prev_reset <= reset;
    if (reset && !prev_reset) begin
      shifting <= 1'b1;
      counter <= 2'd0;
    end else if (shifting) begin
      if (counter == 2'd3) begin
        shifting <= 1'b0;
        counter <= 2'd0;
      end else begin
        counter <= counter + 2'd1;
      end
    end
  end
endmodule