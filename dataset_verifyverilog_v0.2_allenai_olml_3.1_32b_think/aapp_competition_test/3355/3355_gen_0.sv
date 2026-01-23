module scavenger_hunt (
input clk,
input rst_n,
input start,
input [2:0] task_idx,
input [7:0] p_in,
input [7:0] t_in,
input [7:0] d_in,
input [7:0] dist_in,
input [3:0] dist_src,
input [3:0] dist_dst,
output reg [7:0] max_points,
output reg [5:0] best_mask,
output reg done
);
reg [7:0] p_reg [6:0];
reg [7:0] t_reg [6:0];
reg [7:0] d_reg [6:0];
reg [7:0] dist_reg [7:0][7:0];
reg [2:0] state;
reg [5:0] current_mask;
reg [5:0] max_mask;
reg [7:0] max_points_reg;
reg [2:0] k;
reg [15:0] factorial_k;
reg [5:0] current_permutation;
reg [3:0] tasks_in_subset [6:0];
reg [3:0] current_task;
reg [15:0] current_time;
reg [3:0] prev_location;
reg [2:0] path_state;
reg [2:0] task_idx_in_perm;
reg done_reg;
assign max_points = max_points_reg;
assign best_mask = max_mask;
assign done = done_reg;
always @(posedge clk) begin
  if (!rst_n) begin
    state <= 3'b000;
    current_mask <= 6'b00000;
    max_mask <= 6'b00000;
    max_points_reg <= 8'b00000000;
    k <= 3'b000;
    factorial_k <= 16'b0000000000000000;
    current_permutation <= 5'b00000;
    current_time <= 16'b0000000000000000;
    prev_location <= 4'd6;
    path_state <= 2'b00;
    task_idx_in_perm <= 2'b00;
    done_reg <= 1'b0;
    p_reg <= 8'b00000000;
    t_reg <= 8'b00000000;
    d_reg <= 8'b00000000;
    dist_reg <= 8'b00000000;
  end else begin
    if (state == 3'b000) begin
      if (start == 1'b1) state <= 3'b001;
    end else if (state == 3'b001) begin
      if (current_mask < 64) begin
        current_mask <= current_mask + 1;
      end else begin
        state <= 3'b010;
        done_reg <= 1'b1;
      end
    end
  end
end
always @(posedge clk) begin
  if (!rst_n) begin
  end else begin
    if (task_idx >= 3'd0 && task_idx <= 3'd5) begin
      p_reg[task_idx] <= p_in;
      t_reg[task_idx] <= t_in;
      d_reg[task_idx] <= d_in;
    end
    dist_reg[dist_src][dist_dst] <= dist_in;
  end
end
endmodule