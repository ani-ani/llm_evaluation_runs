module TopModule(input clk, input reset, output logic shift_ena);
  logic reset_prev;
  logic [1:0] counter;
  logic active;

  always_ff @(posedge clk) begin
    reset_prev <= reset;

    if (reset && !reset_prev) begin
      active <= 1'b1;
      counter <= 2'b00;
    end else if (active) begin
      if (counter == 2'b11) begin
        active <= 1'b0;
      end else begin
        counter <= counter + 1'b1;
      end
    end
  end

  assign shift_ena = active;
endmodule