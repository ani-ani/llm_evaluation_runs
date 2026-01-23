module mirko_wins (
input clk
input rst_n
input start
input [4:0] N
output reg [29:0] result
output reg done
);

reg [29:0] result_reg;
reg done_reg;
reg [2:0] state;
reg [18:0] counter;

parameter S_IDLE = 3'd0, S_PRE = 3'd1, S_ITER = 3'd2, S_DONE = 3'd3;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    result_reg <= 32'd0;
    done_reg <= 1'b0;
    state <= S_IDLE;
    counter <= 32'd0;
  end else begin
    if (state == S_IDLE) begin
      if (start) state <= S_PRE;
    end
  end
end

assign result = result_reg;
assign done = done_reg;

endmodule