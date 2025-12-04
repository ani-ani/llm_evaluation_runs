module maze_navigator(
  input clk,
  input rst_n,
  input start,
  input [2:0] start_row,
  input [2:0] start_col,
  input [2:0] max_left,
  input [2:0] max_right,
  input [63:0] grid,
  output reg [5:0] reachable_count,
  output reg done
);

typedef enum logic [1:0] {IDLE, PROCESSING, DONE} state_t;
state_t state_reg, state_next;

logic [63:0] visited_reg, visited_next;
logic [2:0] rem_left_reg [0:63];
logic [2:0] rem_right_reg [0:63];
logic [2:0] rem_left_next [0:63];
logic [2:0] rem_right_next [0:63];

logic [11:0] queue_mem [0:63]; // {row, col, rem_left, rem_right}
logic [5:0] head_reg, head_next;
logic [5:0] tail_reg, tail_next;
logic [5:0] cycle_count_reg, cycle_count_next;

logic done_next;
logic [5:0] reachable_count_next;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state_reg <= IDLE;
    visited_reg <= 64'h0;
    foreach (rem_left_reg[i]) rem_left_reg[i] <= 3'h0;
    foreach (rem_right_reg[i]) rem_right_reg[i] <= 3'h0;
    head_reg <= 6'h0;
    tail_reg <= 6'h0;
    cycle_count_reg <= 6'h0;
    reachable_count <= 6'h0;
    done <= 1'b0;
  end else begin
    state_reg <= state_next;
    visited_reg <= visited_next;
    rem_left_reg <= rem_left_next;
    rem_right_reg <= rem_right_next;
    head_reg <= head_next;
    tail_reg <= tail_next;
    cycle_count_reg <= cycle_count_next;
    reachable_count <= reachable_count_next;
    done <= done_next;
  end
end

always_comb begin
  state_next = state_reg;
  visited_next = visited_reg;
  rem_left_next = rem_left_reg;
  rem_right_next = rem_right_reg;
  head_next = head_reg;
  tail_next = tail_reg;
  cycle_count_next = cycle_count_reg;
  done_next = 1'b0;
  reachable_count_next = reachable_count;

  case (state_reg)
    IDLE: begin
      if (start) begin
        visited_next = 64'h0;
        foreach (rem_left_next[i]) rem_left_next[i] = 3'h0;
        foreach (rem_right_next[i]) rem_right_next[i] = 3'h0;

        // Enqueue starting position
        head_next = 6'h0;
        tail_next = 6'h1;
        queue_mem[6'h0] = {start_row, start_col, max_left, max_right};
        
        // Mark as visited
        visited_next[start_row * 8 + start_col] = 1'b1;
        rem_left_next[start_row * 8 + start_col] = max_left;
        rem_right_next[start_row * 8 + start_col] = max_right;
        
        cycle_count_next = 6'h0;
        state_next = PROCESSING;
      end
    end

    PROCESSING: begin
      if (head_reg != tail_reg) begin
        // Dequeue current cell
        automatic logic [11:0] current = queue_mem[head_reg];
        automatic logic [2:0] curr_row = current[11:9];
        automatic logic [2:0] curr_col = current[8:6];
        automatic logic [2:0] curr_rem_left = current[5:3];
        automatic logic [2:0] curr_rem_right = current[2:0];
        head_next = head_reg + 6'h1;

        // Process all 4 directions
        // Up
        begin
          automatic logic [2:0] new_row = curr_row - 1;
          automatic logic [2:0] new_col = curr_col;
          automatic logic [2:0] new_rem_left = curr_rem_left;
          automatic logic [2:0] new_rem_right = curr_rem_right;
          automatic logic [5:0] new_idx = new_row * 8 + new_col;
          
          if (new_row < 8 && new_col < 8 && !grid[new_idx]) begin
            if ((!visited_reg[new_idx]) || 
                (new_rem_left > rem_left_reg[new_idx]) || 
                (new_rem_right > rem_right_reg[new_idx])) begin
              visited_next[new_idx] = 1'b1;
              rem_left_next[new_idx] = new_rem_left;
              rem_right_next[new_idx] = new_rem_right;
              
              if ((tail_next + 6'h1) != head_next) begin
                queue_mem[tail_next] = {new_row, new_col, new_rem_left, new_rem_right};
                tail_next = tail_next + 6'h1;
              end
            end
          end
        end

        // Down
        begin
          automatic logic [2:0] new_row = curr_row + 1;
          automatic logic [2:0] new_col = curr_col;
          automatic logic [2:0] new_rem_left = curr_rem_left;
          automatic logic [2:0] new_rem_right = curr_rem_right;
          automatic logic [5:0] new_idx = new_row * 8 + new_col;
          
          if (new_row < 8 && new_col < 8 && !grid[new_idx]) begin
            if ((!visited_reg[new_idx]) || 
                (new_rem_left > rem_left_reg[new_idx]) || 
                (new_rem_right > rem_right_reg[new_idx])) begin
              visited_next[new_idx] = 1'b1;
              rem_left_next[new_idx] = new_rem_left;
              rem_right_next[new_idx] = new_rem_right;
              
              if ((tail_next + 6'h1) != head_next) begin
                queue_mem[tail_next] = {new_row, new_col, new_rem_left, new_rem_right};
                tail_next = tail_next + 6'h1;
              end
            end
          end
        end

        // Left
        begin
          if (curr_rem_left > 0) begin
            automatic logic [2:0] new_row = curr_row;
            automatic logic [2:0] new_col = curr_col - 1;
            automatic logic [2:0] new_rem_left = curr_rem_left - 1;
            automatic logic [2:0] new_rem_right = curr_rem_right;
            automatic logic [5:0] new_idx = new_row * 8 + new_col;
            
            if (new_row < 8 && new_col < 8 && !grid[new_idx]) begin
              if ((!visited_reg[new_idx]) || 
                  (new_rem_left > rem_left_reg[new_idx]) || 
                  (new_rem_right > rem_right_reg[new_idx])) begin
                visited_next[new_idx] = 1'b1;
                rem_left_next[new_idx] = new_rem_left;
                rem_right_next[new_idx] = new_rem_right;
                
                if ((tail_next + 6'h1) != head_next) begin
                  queue_mem[tail_next] = {new_row, new_col, new_rem_left, new_rem_right};
                  tail_next = tail_next + 6'h1;
                end
              end
            end
          end
        end

        // Right
        begin
          if (curr_rem_right > 0) begin
            automatic logic [2:0] new_row = curr_row;
            automatic logic [2:0] new_col = curr_col + 1;
            automatic logic [2:0] new_rem_left = curr_rem_left;
            automatic logic [2:0] new_rem_right = curr_rem_right - 1;
            automatic logic [5:0] new_idx = new_row * 8 + new_col;
            
            if (new_row < 8 && new_col < 8 && !grid[new_idx]) begin
              if ((!visited_reg[new_idx]) || 
                  (new_rem_left > rem_left_reg[new_idx]) || 
                  (new_rem_right > rem_right_reg[new_idx])) begin
                visited_next[new_idx] = 1'b1;
                rem_left_next[new_idx] = new_rem_left;
                rem_right_next[new_idx] = new_rem_right;
                
                if ((tail_next + 6'h1) != head_next) begin
                  queue_mem[tail_next] = {new_row, new_col, new_rem_left, new_rem_right};
                  tail_next = tail_next + 6'h1;
                end
              end
            end
          end
        end
      end

      cycle_count_next = cycle_count_reg + 6'h1;
      if (cycle_count_reg >= 63 || head_next == tail_next) state_next = DONE;
    end

    DONE: begin
      automatic logic [5:0] count = 0;
      for (int i = 0; i < 64; i++) count += visited_reg[i];
      reachable_count_next = count;
      done_next = 1'b1;
      state_next = IDLE;
    end
  endcase
end

endmodule