module loda_teleport (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_strings,
  input [7:0] strings [0:7],
  output reg [3:0] result,
  output reg done
);

reg [2:0] state;
reg [3:0] dp [0:7];
reg [3:0] max_len;
reg done_reg;

localparam IDLE = 3'd0,
          COMPUTE = 3'd1,
          DONE = 3'd2;

always @(posedge clk) begin
  if (!rst_n) begin
    state <= IDLE;
    done_reg <= 1'b0;
    max_len <= 4'd0;
    dp[0] <=4'd0;
    dp[1] <=4'd0;
    dp[2] <=4'd0;
    dp[3] <=4'd0;
    dp[4] <=4'd0;
    dp[5] <=4'd0;
    dp[6] <=4'd0;
    dp[7] <=4'd0;
  end else begin
    if (state == IDLE) begin
      if (start) state <= COMPUTE;
    end else if (state == COMPUTE) begin
      if (num_strings ==1) begin
        dp[0] <=4'd1;
        max_len <=4'd1;
      end else if (num_strings ==2) begin
        dp[0] <=4'd1;
        dp[1] <= dp[0] +1;
        max_len <= dp[1];
      end else begin
        dp[0] <=4'd1;
        dp[1] <=4'd1;
        dp[2] <=4'd1;
        dp[3] <=4'd1;
        dp[4] <=4'd1;
        dp[5] <=4'd1;
        dp[6] <=4'd1;
        dp[7] <=4'd1;
        max_len <=4'd1;
      end
      state <= DONE;
    end
  end
end

assign result = max_len;
assign done = done_reg;

endmodule