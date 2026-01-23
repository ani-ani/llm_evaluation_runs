module bag_capacity (
input clk,
input rst_n,
input [7:0] m,
input [3:0] k,
input start,
output reg [31:0] result,
output reg done
);

localparam integer MOD = 998244353;
localparam IDLE = 2'd0,
       CALC_BASE = 2'd1,
       MULTIPLY = 2'd2,
       DONE = 2'd3;

reg [1:0] state;
reg [7:0] m_reg;
reg [3:0] k_reg;
reg [31:0] result_reg;
reg [2:0] count;

assign result = result_reg;
assign done = (state == DONE);

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      m_reg <= 8'b0;
      k_reg <= 4'b0;
      result_reg <= 32'b0;
      count <= 3'b0;
   end else begin
      case (state)
         IDLE: begin
            if (start == 1) begin
               m_reg <= m;
               k_reg <= k;
               state <= CALC_BASE;
            end else begin
               state <= IDLE;
            end
         end
         CALC_BASE: begin
            state <= MULTIPLY;
            result_reg <= 32'd1;
            count <= k_reg;
         end
         MULTIPLY: begin
            if (count == 0) begin
               state <= DONE;
            end else begin
               result_reg <= (result_reg * (2 * m_reg + 1)) % MOD;
               count <= count - 1;
               state <= MULTIPLY;
            end
         end
         DONE: state <= DONE;
      endcase
   end
end
endmodule