module scavenger_hunt(
  input clk,
  input rst_n,
  input start,
  input [10:0] total_time,
  input [10:0] travel_matrix [0:5][0:5],
  input [6:0] p_i [0:3],
  input [10:0] t_i [0:3],
  input [10:0] d_i [0:3],
  output reg [8:0] max_points,
  output reg [3:0] task_set,
  output reg done
);

  reg [3:0] state;
  reg [8:0] max_points_reg;
  reg [3:0] task_set_reg;
  reg done_reg;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 4'd0;
      max_points_reg <= 9'd0;
      task_set_reg <= 4'd0;
      done_reg <= 1'b0;
    end
    else begin
      if (start) begin
        state <= 4'd0;
        max_points_reg <= 9'd0;
        task_set_reg <= 4'd0;
        done_reg <= 1'b0;
      end
      else if (!done_reg) begin
        if (state == 4'd15) begin
          done_reg <= 1'b1;
        end
        else begin
          state <= state + 1;
        end
      end
    end
  end
  
  always @(posedge clk) begin
    if (rst_n && !done_reg && !start) begin
      if (current_valid) begin
        if ((current_sum_p > max_points_reg) ||
            ((current_sum_p == max_points_reg) && (state < task_set_reg))) begin
          max_points_reg <= current_sum_p;
          task_set_reg <= state;
        end
      end
    end
  end
  
  logic current_valid;
  logic [8:0] current_sum_p;
  
  always_comb begin
    current_valid = 1'b0;
    current_sum_p = 9'd0;
    
    logic [1:0] tasks [0:3];
    integer task_count = 0;
    integer j;
    // Extract tasks in ascending order
    for (int i=0; i<4; i++) begin
      if (state[i]) begin
        tasks[task_count] = i;
        task_count++;
      end
    end
    
    if (task_count == 0) begin
      // Path: start -> end
      logic [10:0] total_time_needed = travel_matrix[4][5];
      current_valid = (total_time_needed <= total_time);
      current_sum_p = 9'd0;
    end
    else begin
      logic [10:0] travel_sum = travel_matrix[4][tasks[0]];
      logic [10:0] arrival_times [3:0];
      logic [10:0] path_time = travel_sum + t_i[tasks[0]];
      logic all_deadlines_met = 1'b1;
      arrival_times[0] = travel_sum;
      
      // Check deadline for first task
      if (d_i[tasks[0]] != 11'h7FF && arrival_times[0] > d_i[tasks[0]]) 
        all_deadlines_met = 1'b0;
      
      for (j=1; j<task_count; j++) begin
        travel_sum = travel_sum + travel_matrix[tasks[j-1]][tasks[j]];
        arrival_times[j] = arrival_times[j-1] + t_i[tasks[j-1]] + travel_matrix[tasks[j-1]][tasks[j]];
        path_time = path_time + travel_matrix[tasks[j-1]][tasks[j]] + t_i[tasks[j]];
        
        if (d_i[tasks[j]] != 11'h7FF && arrival_times[j] > d_i[tasks[j]]) 
          all_deadlines_met = 1'b0;
      end
      
      path_time = path_time + travel_matrix[tasks[task_count-1]][5];
      current_valid = (path_time <= total_time) && all_deadlines_met;
      
      // Calculate points
      current_sum_p = p_i[tasks[0]] + p_i[tasks[1]] + p_i[tasks[2]] + p_i[tasks[3]];
      case(task_count)
        1: current_sum_p = p_i[tasks[0]];
        2: current_sum_p = p_i[tasks[0]] + p_i[tasks[1]];
        3: current_sum_p = p_i[tasks[0]] + p_i[tasks[1]] + p_i[tasks[2]];
        default: current_sum_p = current_sum_p; // 4
      endcase
    end
  end
  
  always @(*) begin
    max_points = done_reg ? max_points_reg : 9'd0;
    task_set = done_reg ? task_set_reg : 4'd0;
    done = done_reg;
  end
  
endmodule