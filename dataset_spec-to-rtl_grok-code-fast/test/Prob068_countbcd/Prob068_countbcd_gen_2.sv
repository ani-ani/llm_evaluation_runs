module TopModule(
  input clk,
  input reset,
  output [2:0] ena,
  output [15:0] q
);

  reg [3:0] ones_reg;
  reg [3:0] tens_reg;
  reg [3:0] hun_reg;
  reg [3:0] thou_reg;
  reg [2:0] ena_reg;

  assign q = {thou_reg, hun_reg, tens_reg, ones_reg};
  assign ena = ena_reg;

  always @(posedge clk) begin
    if (reset) begin
      ones_reg <= 4'b0000;
      tens_reg <= 4'b0000;
      hun_reg <= 4'b0000;
      thou_reg <= 4'b0000;
      ena_reg <= 3'b000;
    end else begin
      // Default enable signals
      ena_reg <= 3'b000;
      // Always increment the ones digit
      if (ones_reg < 9) begin
        ones_reg <= ones_reg + 4'd1;
      end else begin
        ones_reg <= 4'd0;
        // Increment tens digit
        if (tens_reg < 9) begin
          tens_reg <= tens_reg + 4'd1;
          ena_reg[0] <= 1'b1;
        end else begin
          tens_reg <= 4'd0;
          // Increment hundreds digit
          if (hun_reg < 9) begin
            hun_reg <= hun_reg + 4'd1;
            ena_reg[1] <= 1'b1;
          end else begin
            hun_reg <= 4'd0;
            // Increment thousands digit
            if (thou_reg < 9) begin
              thou_reg <= thou_reg + 4'd1;
              ena_reg[2] <= 1'b1;
            end else begin
              thou_reg <= 4'd0;
            end
          end
        end
      end
    end
  end
endmodule