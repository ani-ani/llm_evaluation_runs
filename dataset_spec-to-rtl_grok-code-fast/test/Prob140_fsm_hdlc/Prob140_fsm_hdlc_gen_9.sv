module TopModule(
  input clk,
  input reset,
  input in,
  output reg disc,
  output reg flag,
  output reg err
);
  reg [2:0] counter;
  reg next_disc, next_flag, next_err;
  always @(posedge clk) begin
    if (reset) begin
      counter <= 3'd0;
      disc <= 1'b0;
      flag <= 1'b0;
      err <= 1'b0;
      next_disc <= 1'b0;
      next_flag <= 1'b0;
      next_err <= 1'b0;
    end else begin
      next_disc <= 1'b0;
      next_flag <= 1'b0;
      next_err <= 1'b0;
      if (in == 1'b0) begin
        case (counter)
          3'd5: next_disc <= 1'b1;
          3'd6: next_flag <= 1'b1;
          default: if (counter >= 3'd7) next_err <= 1'b1;
        endcase
        counter <= 3'd0;
      end else begin
        if (counter < 3'd7) counter <= counter + 3'd1;
      end
      disc <= next_disc;
      flag <= next_flag;
      err <= next_err;
    end
  end
endmodule