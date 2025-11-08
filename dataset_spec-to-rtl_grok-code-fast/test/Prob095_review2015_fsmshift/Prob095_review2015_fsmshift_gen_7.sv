module TopModule(input clk, input reset, output reg shift_ena);
  reg [1:0] cnt;
  always @(posedge clk) begin
    if (reset) begin
      shift_ena <= 1'b1;
      cnt <= 2'd0;
    end else begin
      if (shift_ena) begin
        if (cnt == 2'd2) begin
          cnt <= cnt + 1;
        end else if (cnt == 2'd3) begin
          shift_ena <= 1'b0;
        end else begin
          cnt <= cnt + 1;
        end
      end
    end
  end
endmodule