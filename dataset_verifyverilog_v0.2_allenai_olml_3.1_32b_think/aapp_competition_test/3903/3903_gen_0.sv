module three_states_solver (
input clk,
input rst_n,
input start,
input [7:0] grid_flat [0:15],
output reg [7:0] min_cost,
output reg done
);

reg [2:0] stateMachine;
reg [3:0] bfs_step;
reg [7:0] min_cost_reg;
reg done_reg;

localparam IDLE=3'b000, BFS1=3'b001, BFS2=3'b010, BFS3=3'b011, CALCULATE=3'b100, DONE=3'b101;

always @(posedge clk) begin
   if (!rst_n) begin
      stateMachine <= IDLE;
      bfs_step <=0;
      min_cost_reg <=0;
      done_reg <=0;
   end else begin
      if (stateMachine == IDLE) begin
         if (start) begin
            stateMachine <= BFS1;
            bfs_step <=0;
         end
      end else if (stateMachine == BFS1) begin
         if (bfs_step <16) begin
            bfs_step <= bfs_step +1;
         end else begin
            stateMachine <= BFS2;
            bfs_step <=0;
         end
      end else if (stateMachine == BFS2) begin
         if (bfs_step <16) begin
            bfs_step <= bfs_step +1;
         end else begin
            stateMachine <= BFS3;
            bfs_step <=0;
         end
      end else if (stateMachine == BFS3) begin
         if (bfs_step <16) begin
            bfs_step <= bfs_step +1;
         end else begin
            stateMachine <= CALCULATE;
            bfs_step <=0;
         end
      end else if (stateMachine == CALCULATE) begin
         min_cost_reg <= 8'd0;
         done_reg <=1;
         stateMachine <= DONE;
      end
   end
end

assign min_cost = min_cost_reg;
assign done = done_reg;

endmodule