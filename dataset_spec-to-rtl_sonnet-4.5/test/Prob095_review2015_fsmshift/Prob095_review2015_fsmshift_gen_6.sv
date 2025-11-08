module TopModule(
  input clk,
  input reset,
  output shift_ena
);

  reg [2:0] counter;
  reg shift_active;

  always @(posedge clk) begin
    if (reset) begin
      counter <= 3'd0;
      shift_active <= 1'b1;
    end else begin
      if (shift_active) begin
        if (counter == 3'd3) begin
          counter <= 3'd0;
          shift_active <= 1'b0;
        end else begin
          counter <= counter + 1'b1;
        end
      end
    end
  end

  assign shift_ena = shift_active;

endmodule