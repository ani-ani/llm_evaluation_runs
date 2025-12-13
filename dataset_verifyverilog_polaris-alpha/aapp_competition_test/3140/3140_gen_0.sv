module fish_point_counter(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [1:0]  x0,
  input  logic [1:0]  y0,
  input  logic [4:0]  k_val,
  input  logic [4:0]  l_val,
  input  logic [4:0]  t_grid [0:3][0:3],
  output logic [4:0]  count,
  output logic        done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE       = 2'b00,
    BFS_DEQ    = 2'b01,
    BFS_NEIGH  = 2'b10,
    DONE_ST    = 2'b11
  } state_t;

  state_t state, next_state;

  // Visited bitmap: bit index = y*4 + x
  logic [15:0] visited;

  // BFS queue: 16 entries, each 11 bits: {time[4:0], y[2:0], x[2:0]}
  // But x,y are 2 bits; store as 3 bits with MSB 0 for simplicity
  typedef struct packed {
    logic [4:0] t;
    logic [1:0] y;
    logic [1:0] x;
  } q_entry_t;

  q_entry_t queue [0:15];
  logic [4:0] head;   // 0-16
  logic [4:0] tail;   // 0-16

  // Current node being expanded
  logic [1:0] cur_x, cur_y;
  logic [4:0] cur_t;

  // Neighbor generation control
  logic [1:0] nbr_idx;        // 0..3 for 4 neighbors
  logic       nbr_valid;
  logic [1:0] nbr_x, nbr_y;
  logic [4:0] nbr_arrival_t;
  logic       nbr_in_range;
  logic       nbr_not_visited;
  logic       nbr_time_ok;
  logic       enqueue_nbr;

  // Queue empty
  logic queue_empty;

  // Helper: index into visited
  function automatic logic [3:0] idx(input logic [1:0] x, input logic [1:0] y);
    idx = {y, x};
  endfunction

  // Queue empty detection
  assign queue_empty = (head == tail);

  // Combinational neighbor selection
  always_comb begin
    nbr_valid      = 1'b0;
    nbr_x          = 2'd0;
    nbr_y          = 2'd0;
    nbr_arrival_t  = cur_t + 5'd1;

    unique case (nbr_idx)
      2'd0: begin // up: (x, y-1)
        if (cur_y > 0) begin
          nbr_valid = 1'b1;
          nbr_x     = cur_x;
          nbr_y     = cur_y - 2'd1;
        end
      end
      2'd1: begin // down: (x, y+1)
        if (cur_y < 2'd3) begin
          nbr_valid = 1'b1;
          nbr_x     = cur_x;
          nbr_y     = cur_y + 2'd1;
        end
      end
      2'd2: begin // left: (x-1, y)
        if (cur_x > 0) begin
          nbr_valid = 1'b1;
          nbr_x     = cur_x - 2'd1;
          nbr_y     = cur_y;
        end
      end
      2'd3: begin // right: (x+1, y)
        if (cur_x < 2'd3) begin
          nbr_valid = 1'b1;
          nbr_x     = cur_x + 2'd1;
          nbr_y     = cur_y;
        end
      end
      default: begin
        nbr_valid = 1'b0;
      end
    endcase

    nbr_in_range     = nbr_valid;
    nbr_not_visited  = nbr_valid && !visited[idx(nbr_x, nbr_y)];

    // Time constraints for neighbor
    // arrival time <= l_val
    // arrival time in [t_grid[x][y], t_grid[x][y] + k_val)
    nbr_time_ok = 1'b0;
    if (nbr_not_visited && (nbr_arrival_t <= l_val)) begin
      if ( (nbr_arrival_t >= t_grid[nbr_x][nbr_y]) &&
           (nbr_arrival_t < (t_grid[nbr_x][nbr_y] + k_val)) ) begin
        nbr_time_ok = 1'b1;
      end
    end

    enqueue_nbr = nbr_in_range && nbr_not_visited && nbr_time_ok;
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    unique case (state)
      IDLE: begin
        if (start) begin
          next_state = BFS_DEQ;
        end
      end
      BFS_DEQ: begin
        if (queue_empty) begin
          next_state = DONE_ST;
        end else begin
          next_state = BFS_NEIGH;
        end
      end
      BFS_NEIGH: begin
        if (nbr_idx == 2'd3) begin
          // After last neighbor processed, go back to dequeue
          next_state = BFS_DEQ;
        end else begin
          next_state = BFS_NEIGH;
        end
      end
      DONE_ST: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      visited  <= 16'b0;
      head     <= 5'd0;
      tail     <= 5'd0;
      count    <= 5'd0;
      done     <= 1'b0;
      cur_x    <= 2'd0;
      cur_y    <= 2'd0;
      cur_t    <= 5'd0;
      nbr_idx  <= 2'd0;
      for (i = 0; i < 16; i = i + 1) begin
        queue[i].t <= 5'd0;
        queue[i].x <= 2'd0;
        queue[i].y <= 2'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done    <= 1'b0;
          count   <= 5'd0;
          visited <= 16'b0;
          head    <= 5'd0;
          tail    <= 5'd0;
          nbr_idx <= 2'd0;

          if (start) begin
            // Initialize BFS with starting point at time = 1
            // Check if starting point itself is valid
            // Conditions: 1 <= l_val, 1 in [t_grid[x0][y0], t_grid[x0][y0] + k_val)
            logic start_valid;
            start_valid = 1'b0;
            if (5'd1 <= l_val) begin
              if ( (5'd1 >= t_grid[x0][y0]) &&
                   (5'd1 < (t_grid[x0][y0] + k_val)) ) begin
                start_valid = 1'b1;
              end
            end

            if (start_valid) begin
              visited[idx(x0, y0)] <= 1'b1;
              queue[0].x <= x0;
              queue[0].y <= y0;
              queue[0].t <= 5'd1;
              head       <= 5'd0;
              tail       <= 5'd1;
              count      <= 5'd1;
            end else begin
              // Start not valid: empty queue, will go to DONE_ST
              head  <= 5'd0;
              tail  <= 5'd0;
              count <= 5'd0;
            end
          end
        end

        BFS_DEQ: begin
          done <= 1'b0;
          if (!queue_empty) begin
            cur_x   <= queue[head].x;
            cur_y   <= queue[head].y;
            cur_t   <= queue[head].t;
            head    <= head + 5'd1;
            nbr_idx <= 2'd0;
          end
        end

        BFS_NEIGH: begin
          done <= 1'b0;
          // Process current neighbor based on nbr_idx and enqueue_nbr
          if (enqueue_nbr) begin
            // Mark visited and enqueue
            visited[idx(nbr_x, nbr_y)] <= 1'b1;
            queue[tail].x <= nbr_x;
            queue[tail].y <= nbr_y;
            queue[tail].t <= nbr_arrival_t;
            tail          <= tail + 5'd1;
            count         <= count + 5'd1;
          end

          // Advance neighbor index
          if (nbr_idx != 2'd3) begin
            nbr_idx <= nbr_idx + 2'd1;
          end else begin
            nbr_idx <= 2'd0; // Will be reset for next node in BFS_DEQ
          end
        end

        DONE_ST: begin
          done <= 1'b1;
          // Hold count, visited, queue as-is until next start after IDLE transition
        end

        default: begin
          // Should not occur; safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule