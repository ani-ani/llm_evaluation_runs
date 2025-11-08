module TopModule (
  input clk,
  input reset,
  output shift_ena
);
  reg [1:0] counter;
  reg reset_prev;
  reg counting;

  always @(posedge clk) begin
    reset_prev <= reset;
  end

  wire reset_falling = reset_prev && !reset;

  always @(posedge clk) begin
    if (reset) begin
      counting <= 1'b0;
      counter <= 2'b0;
    end else begin
      if (reset_falling) begin
        counting <= 1'b1;
        counter <= 2'b0;
      end else if (counting) begin
        if (counter < 2'b11) begin
          counter <= counter + 1;
        end else begin
          counting <= 1'b0;
        end
      end
    end
  end

  assign shift_ena = counting;

endmodule