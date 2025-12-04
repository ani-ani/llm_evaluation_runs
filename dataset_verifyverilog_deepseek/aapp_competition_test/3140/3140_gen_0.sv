module fish_point_counter (
  input clk,
  input rst_n,
  input start,
  input [1:0] x0,
  input [1:0] y0,
  input [4:0] k_val,
  input [4:0] l_val,
  input [4:0] t_grid [0:3][0:3],
  output reg [4:0] count,
  output reg done
);

  // State encodings
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] BFS_EXPAND = 2'b01;
  localparam [1:0] BFS_CHECK = 2'b10;
  localparam [1:0] DONE = 2'b11;

  reg [1:0] state, next_state;
  reg [3:0] head_ptr, next_head_ptr;
  reg [3:0] tail_ptr, next_tail_ptr;
  reg [15:0] visited, next_visited;
  reg [14:0] queue [0:15];  // {x[4:0], y[4:0], time[4:0]}
  reg [4:0] curr_x, curr_y, curr_time;
  reg [4:0] count_r, next_count;
  reg done_r, next_done;
  
  // Neighbor computation
  wire [1:0] neighbor_x [0:3];
  wire [1:0] neighbor_y [0:3];
  wire [4:0] new_time = curr_time + 5'd1;
  wire [3:0] valid_flags;
  wire [3:0] valid_count = valid_flags[0] + valid_flags[1] + valid_flags[2] + valid_flags[3];

  // Define neighbor offsets
  assign neighbor_x[0] = curr_x[1:0] + 1;
  assign neighbor_y[0] = curr_y[1:0];
  assign neighbor_x[1] = curr_x[1:0] - 1;
  assign neighbor_y[1] = curr_y[1:0];
  assign neighbor_x[2] = curr_x[1:0];
  assign neighbor_y[2] = curr_y[1:0] + 1;
  assign neighbor_x[3] = curr_x[1:0];
  assign neighbor_y[3] = curr_y[1:0] - 1;

  // Validity check per neighbor
  genvar i;
  generate
    for (i=0; i<4; i++) begin
      wire [1:0] nx = neighbor_x[i];
      wire [1:0] ny = neighbor_y[i];
      wire in_bounds = (nx < 2'b11) && (ny < 2'b11) && (nx[1] || nx[0]) <= 1 && (ny[1] || ny[0]) <= 1;
      wire not_visited = !visited[{ny, nx}];
      wire [4:0] t_xy = t_grid[nx][ny];
      wire time_ok = (new_time <= l_val) && (new_time >= t_xy) && (new_time < (t_xy + k_val));
      assign valid_flags[i] = in_bounds && not_visited && time_ok;
    end
  endgenerate

  always_comb begin
    next_state = state;
    next_head_ptr = head_ptr;
    next_tail_ptr = tail_ptr;
    next_visited = visited;
    next_count = count_r;
    next_done = done_r;

    case(state)
      IDLE: begin
        if (start) begin
          next_visited = 16'h0;
          next_head_ptr = 4'h0;
          next_tail_ptr = 4'h0;
          next_count = 0;
          
          if ((1 >= t_grid[x0][y0]) && (1 < (t_grid[x0][y0] + k_val)) && (1 <= l_val)) begin
            next_visited[ {y0, x0} ] = 1'b1;
            next_tail_ptr = 4'h1;
            next_count = 5'd1;
          end
          next_state = BFS_EXPAND;
          next_done = 1'b0;
        end
      end
      
      BFS_EXPAND: begin
        if (head_ptr == tail_ptr) begin
          next_state = DONE;
          next_done = 1'b1;
        end else begin
          next_state = BFS_CHECK;
          next_head_ptr = head_ptr + 1;
        end
      end
      
      BFS_CHECK: begin
        next_state = BFS_EXPAND;
        if (|valid_flags) begin
          next_visited = visited;
          for (integer j=0; j<4; j++) begin
            if (valid_flags[j]) begin
              next_visited[ {neighbor_y[j], neighbor_x[j]} ] = 1'b1;
            end
          end
          next_count = count_r + valid_count;
        end
      end
      
      DONE: begin
        next_done = 1'b1;
        next_state = IDLE;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      head_ptr <= 0;
      tail_ptr <= 0;
      visited <= 0;
      count_r <= 0;
      done_r <= 0;
      for (int i=0; i<16; i++) queue[i] <= '0;
      curr_x <= 0;
      curr_y <= 0;
      curr_time <= 0;
    end else begin
      state <= next_state;
      head_ptr <= next_head_ptr;
      tail_ptr <= next_tail_ptr;
      visited <= next_visited;
      count_r <= next_count;
      done_r <= next_done;

      // Queue operations
      if (state == IDLE && start) begin
        if ((1 >= t_grid[x0][y0]) && (1 < (t_grid[x0][y0] + k_val)) && (1 <= l_val)) begin
          queue[0] <= {3'b0, x0, 3'b0, y0, 5'd1};
        end
      end
      
      if (state == BFS_EXPAND && head_ptr != tail_ptr) begin
        curr_x <= queue[head_ptr][14:10];
        curr_y <= queue[head_ptr][9:5];
        curr_time <= queue[head_ptr][4:0];
      end
      
      if (state == BFS_CHECK) begin
        integer idx = tail_ptr;
        for (int j=0; j<4; j++) begin
          if (valid_flags[j] && (idx < 16)) begin
            queue[idx] <= {3'b0, neighbor_x[j], 3'b0, neighbor_y[j], new_time};
            idx = idx + 1;
          end
        end
      end
    end
  end

  assign count = count_r;
  assign done = done_r;

endmodule