module largest_divisor (input clk, input rst_n, input start, input [7:0] n, output reg [7:0] result, output reg done);
localparam IDLE = 3'd0;
localparam CHECK = 3'd1;
localparam ITERATE = 3'd2;
localparam DONE = 3'd3;
reg [7:0] n_val;
reg [2:0] state;
reg [7:0] candidate;
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      n_val <= 8'b0;
      candidate <= 8'b0;
      result <= 8'b1;
      done <= 1'b0;
   end else begin
      state <= state;
      n_val <= n_val;
      candidate <= candidate;
      result <= result;
      done <= done;
case (state)
IDLE: begin
   if (start) begin
      n_val <= n;
   end
end

CHECK: begin
   if (n_val % candidate == 0) begin
      result <= candidate;
      done <= 1'b1;
      state <= DONE;
   end else begin
      state <= ITERATE;
   end
end

ITERATE: begin
   candidate <= candidate - 1;
   state <= CHECK;
end

DONE: begin
   if (start) begin
      n_val <= n;
      candidate <= 8'b0;
      state <= IDLE;
   end else begin
      state <= DONE;
   end
end
endcase

if (state == IDLE) begin
   if (n_val <= 1) begin
      result <= 8'b1;
      done <= 1'b1;
      state <= DONE;
   end else if (candidate == 8'b0) begin
      candidate <= n_val - 1;
      state <= CHECK;
   end
end
end
endmodule