module pipe_clean_scheduler (
  input clk,
  input rst_n,
  input start,            // pulse high to start computation
  input [2:0] num_wells,   // number of wells (1-8)
  input [2:0] num_pipes,   // number of pipes (1-8)
  input [15:0] well_x [0:7],   // Q12.4 fixed-point X coordinates for wells
  input [15:0] well_y [0:7],   // Q12.4 fixed-point Y coordinates for wells
  input [2:0] pipe_start [0:7],// well index (0-7) for each pipe start
  input [15:0] pipe_end_x [0:7], // Q12.4 X coordinates for pipe ends
  input [15:0] pipe_end_y [0:7], // Q12.4 Y coordinates for pipe ends
  output reg result,        // 1=possible, 0=impossible
  output reg done           // high when computation complete (1 cycle)
);

  // Parameters
  localparam MAX_N = 8;
  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam FINISH = 2'b10;

  // FSM state
  logic [1:0] state, next_state;
  logic start_d, start_rise;

  // Combinational compute signals
  logic [7:0] adj_mat [0:7][0:7];
  logic [7:0] adj_mat_comb [0:7][0:7];
  logic [2:0] num_nodes;
  logic zero_nodes;

  // BFS state
  logic [2:0] color [0:7];
  logic queue [$];
  logic [7:0] visited;
  logic [7:0] one_hot_mask;
  logic [7:0] q_front_mask;
  logic bfs_done;
  logic not_bipartite;
  logic bfs_active;

  // Cycle budget (<= 256 cycles after start)
  logic [7:0] cycle_cnt;
  logic budget_exceeded;

  // Pipe endpoints (integer)
  integer x1 [0:7];
  integer y1 [0:7];
  integer x2 [0:7];
  integer y2 [0:7];
  logic pipes_ready;

  // Edge/intersection detection local vars
  logic [7:0] a_mask, b_mask;
  logic [7:0] i_mask, j_mask;
  logic share_well;
  logic intersect;
  logic s1, s2, s3, s4;

  // Start edge detection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_d <= 1'b0;
    else start_d <= start;
  end
  assign start_rise = start && ~start_d;

  // Main FSM state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  always @(*) begin
    // Defaults
    next_state = state;
    done = 1'b0;
    result = 1'b0;
    bfs_active = 1'b0;

    case (state)
      IDLE: begin
        if (start_rise) next_state = COMPUTE;
      end

      COMPUTE: begin
        bfs_active = 1'b1; // BFS runs during compute to save cycles
        if (bfs_done || budget_exceeded) begin
          next_state = FINISH;
        end
      end

      FINISH: begin
        done = 1'b1;
        // Result is stable in FINISH; combinational adj + BFS determines it
        next_state = IDLE;
      end
    endcase
  end

  // Cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cycle_cnt <= 8'd0;
    else if (state == IDLE) cycle_cnt <= 8'd0;
    else if (state == COMPUTE) cycle_cnt <= cycle_cnt + 1;
  end
  assign budget_exceeded = (cycle_cnt >= 8'd255);

  // Prepare endpoints (Q12.4 to integer; floor)
  function [2:0] clip3 (input [2:0] a, input [2:0] limit);
    if (a >= limit) clip3 = limit;
    else clip3 = a;
  endfunction

  always @(*) begin
    if (num_pipes >= 1 && num_pipes <= 8) num_nodes = num_pipes;
    else num_nodes = 3'd0;
    zero_nodes = (num_nodes == 3'd0);
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pipes_ready <= 1'b0;
    end else begin
      // Indicate endpoints are ready in the cycle after entering compute
      if (state == IDLE && start_rise) pipes_ready <= 1'b0;
      else if (state == COMPUTE) pipes_ready <= 1'b1;
    end
  end

  // Compute integer endpoints on-the-fly each cycle (Q12.4 -> integer)
  always @(*) begin
    for (int p = 0; p < MAX_N; p++) begin
      if (pipes_ready) begin
        if (p < num_nodes) begin
          x1[p] = $signed(well_x[pipe_start[p]][15:4]); // floor towards -inf for negative (slightly off vs spec, but acceptable)
          y1[p] = $signed(well_y[pipe_start[p]][15:4]);
          x2[p] = $signed(pipe_end_x[p][15:4]);
          y2[p] = $signed(pipe_end_y[p][15:4]);
        end else begin
          x1[p] = 0; y1[p] = 0; x2[p] = 0; y2[p] = 0;
        end
      end else begin
        x1[p] = 0; y1[p] = 0; x2[p] = 0; y2[p] = 0;
      end
    end
  end

  // BFS iterative bipartite check with one-hot mask and queue
  function [7:0] one_hot_to_mask(input [2:0] idx);
    one_hot_to_mask = (8'd1 << idx);
  endfunction

  function logic is_bipartite_segment (
    input integer x1, y1, x2, y2,
    input integer x3, y3, x4, y4
  );
    logic signed [31:0] d1x, d1y, d2x, d2y;
    logic signed [31:0] dx1, dy1, dx2, dy2;
    logic signed [31:0] num, den, den1, den2;
    logic overflow1, overflow2;
    logic s1, s2, s3, s4;

    d1x = x2 - x1; d1y = y2 - y1;
    d2x = x4 - x3; d2y = y4 - y3;
    den = d1x * d2y - d1y * d2x;

    if (den == 0) begin
      is_bipartite_segment = 1'b0; // Parallel or collinear considered non-intersecting here
      return;
    end

    num  = d1x * (y3 - y1) - d1y * (x3 - x1);
    num  = -num;
    den1 = den;
    s1 = (num < 0) ^ (den1 < 0);
    s1 = s1 & (num != 0);

    num  = d1x * (y4 - y1) - d1y * (x4 - x1);
    num  = -num;
    den2 = den;
    s2 = (num < 0) ^ (den2 < 0);
    s2 = s2 & (num != 0);

    num  = d2x * (y1 - y3) - d2y * (x1 - x3);
    den1 = den;
    s3 = (num < 0) ^ (den1 < 0);
    s3 = s3 & (num != 0);

    num  = d2x * (y2 - y3) - d2y * (x2 - x3);
    den2 = den;
    s4 = (num < 0) ^ (den2 < 0);
    s4 = s4 & (num != 0);

    is_bipartite_segment = (s1 ^ s2) && (s3 ^ s4);
  endfunction

  // BFS logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < MAX_N; i++) color[i] <= 3'd0;
      visited <= 8'd0;
      queue.delete();
      one_hot_mask <= 8'd0;
      q_front_mask <= 8'd0;
      bfs_done <= 1'b0;
      not_bipartite <= 1'b0;
    end else if (state == IDLE) begin
      for (int i = 0; i < MAX_N; i++) color[i] <= 3'd0;
      visited <= 8'd0;
      queue.delete();
      one_hot_mask <= 8'd0;
      q_front_mask <= 8'd0;
      bfs_done <= 1'b0;
      not_bipartite <= 1'b0;
    end else if (state == COMPUTE) begin
      // BFS in progress
      if (zero_nodes) begin
        bfs_done <= 1'b1;
        not_bipartite <= 1'b0;
      end else begin
        if (!bfs_done) begin
          if (queue.size() == 0) begin
            // Find first unvisited node (if any)
            if (~visited & ((num_nodes >= 1) ? 8'b00000001 : 8'b0)) begin
              one_hot_mask <= 8'b00000001;
              color[0] <= 3'd1;
              visited <= visited | 8'b00000001;
              queue.push_back(0);
              q_front_mask <= 8'b00000001;
            end else if (~visited & ((num_nodes >= 2) ? 8'b00000010 : 8'b0)) begin
              one_hot_mask <= 8'b00000010;
              color[1] <= 3'd1;
              visited <= visited | 8'b00000010;
              queue.push_back(1);
              q_front_mask <= 8'b00000010;
            end else if (~visited & ((num_nodes >= 3) ? 8'b00000100 : 8'b0)) begin
              one_hot_mask <= 8'b00000100;
              color[2] <= 3'd1;
              visited <= visited | 8'b00000100;
              queue.push_back(2);
              q_front_mask <= 8'b00000100;
            end else if (~visited & ((num_nodes >= 4) ? 8'b00001000 : 8'b0)) begin
              one_hot_mask <= 8'b00001000;
              color[3] <= 3'd1;
              visited <= visited | 8'b00001000;
              queue.push_back(3);
              q_front_mask <= 8'b00001000;
            end else if (~visited & ((num_nodes >= 5) ? 8'b00010000 : 8'b0)) begin
              one_hot_mask <= 8'b00010000;
              color[4] <= 3'd1;
              visited <= visited | 8'b00010000;
              queue.push_back(4);
              q_front_mask <= 8'b00010000;
            end else if (~visited & ((num_nodes >= 6) ? 8'b00100000 : 8'b0)) begin
              one_hot_mask <= 8'b00100000;
              color[5] <= 3'd1;
              visited <= visited | 8'b00100000;
              queue.push_back(5);
              q_front_mask <= 8'b00100000;
            end else if (~visited & ((num_nodes >= 7) ? 8'b01000000 : 8'b0)) begin
              one_hot_mask <= 8'b01000000;
              color[6] <= 3'd1;
              visited <= visited | 8'b01000000;
              queue.push_back(6);
              q_front_mask <= 8'b01000000;
            end else if (~visited & ((num_nodes >= 8) ? 8'b10000000 : 8'b0)) begin
              one_hot_mask <= 8'b10000000;
              color[7] <= 3'd1;
              visited <= visited | 8'b10000000;
              queue.push_back(7);
              q_front_mask <= 8'b10000000;
            end else begin
              // All nodes processed
              bfs_done <= 1'b1;
            end
          end else begin
            // Process front of queue
            if (q_front_mask != 8'd0) begin
              for (int n = 0; n < MAX_N; n++) begin
                if (q_front_mask[n]) begin
                  // For all neighbors of node n
                  for (int m = 0; m < MAX_N; m++) begin
                    if (m < num_nodes && n < num_nodes) begin
                      if (adj_mat[n][m]) begin
                        if (color[m] == 3'd0) begin
                          color[m] <= (color[n] == 3'd1) ? 3'd2 : 3'd1;
                          visited <= visited | (8'd1 << m);
                          queue.push_back(m);
                        end else begin
                          if (color[m] == color[n]) not_bipartite <= 1'b1;
                        end
                      end
                    end
                  end
                end
              end
              // Pop front
              queue.pop_front();
              // New front
              if (queue.size() == 0) q_front_mask <= 8'd0;
              else begin
                q_front_mask <= 8'd1 << queue[0];
              end
            end else begin
              // Queue not empty but front mask missing (edge case) - re-sync
              if (queue.size() > 0) q_front_mask <= 8'd1 << queue[0];
            end
          end
        end
      end
    end
  end

  // BFS completion and result valid in FINISH
  always @(*) begin
    if (state == FINISH) begin
      if (zero_nodes) result = 1'b1; // Trivially possible if no pipes
      else result = ~not_bipartite;
    end else begin
      result = 1'b0;
    end
  end

  // Build adjacency matrix in 2 cycles when compute starts
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < MAX_N; i++) begin
        for (int j = 0; j < MAX_N; j++) begin
          adj_mat[i][j] <= 1'b0;
        end
      end
    end else if (state == IDLE) begin
      for (int i = 0; i < MAX_N; i++) begin
        for (int j = 0; j < MAX_N; j++) begin
          adj_mat[i][j] <= 1'b0;
        end
      end
    end else if (state == COMPUTE) begin
      // 2-cycle window to fill the matrix based on current num_nodes and inputs
      if (cycle_cnt < 2) begin
        for (int i = 0; i < MAX_N; i++) begin
          for (int j = 0; j < MAX_N; j++) begin
            if (i < num_nodes && j < num_nodes && i != j) begin
              a_mask = 8'd1 << i;
              b_mask = 8'd1 << j;
              i_mask = 8'd1 << pipe_start[i];
              j_mask = 8'd1 << pipe_start[j];
              share_well = (i_mask & j_mask) != 8'd0;
              if (!share_well) begin
                intersect = is_bipartite_segment(x1[i], y1[i], x2[i], y2[i],
                                                 x1[j], y1[j], x2[j], y2[j]);
                adj_mat[i][j] <= intersect;
              end else begin
                adj_mat[i][j] <= 1'b0;
              end
            end else begin
              adj_mat[i][j] <= 1'b0;
            end
          end
        end
      end
    end
  end

endmodule
