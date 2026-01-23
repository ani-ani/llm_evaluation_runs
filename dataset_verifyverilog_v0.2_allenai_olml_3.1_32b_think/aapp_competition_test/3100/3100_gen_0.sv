module fruit_arrangement (input clk, input rst_n, input start, input [4:0] A, input [4:0] C, input [4:0] M, output reg [31:0] result, output reg done);
localparam IDLE = 3'd0, INIT = 3'd1, COMPUTE = 3'd2, SUM = 3'd3, DONE = 3'd4;
reg [2:0] state, next_state;
reg [31:0] dp [0:10][0:10][0:10][0:3];
reg [31:0] result;
reg done;
initial begin int a, c, m, last; for (a=0; a<=10; a++) for (c=0; c<=10; c++) for (m=0; m<=10; m++) for (last=0; last<4; last++) dp[a][c][m][last] = 0; dp[0][0][0][0] = 1; end
always @(posedge clk) begin if (!rst_n) begin state <= IDLE; done <=0; result <=0; end else begin case (state) IDLE: begin if (start) next_state = INIT; else next_state = IDLE; end INIT: begin next_state = COMPUTE; end COMPUTE: begin next_state = SUM; end SUM: begin result = dp[A][C][M][1] + dp[A][C][M][2] + dp[A][C][M][3]; if (result > 32'd1000000007) result = result % 32'd1000000007; done <=1; next_state = DONE; end DONE: begin next_state = DONE; end endcase state <= next_state; end end endmodule