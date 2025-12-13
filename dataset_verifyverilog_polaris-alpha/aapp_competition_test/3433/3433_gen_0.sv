module maze_joe_escape(
  input clk,
  input rst_n,
  input start,
  input [15:0][1:0] grid_i,
  output reg [3:0] time_o,
  output reg impossible_o,
  output reg done_o
);

  // Cell encoding
  localparam CELL_WALL  = 2'b00;
  localparam CELL_OPEN  = 2'b01;
  localparam CELL_JOE   = 2'b10;
  localparam CELL_FIRE  = 2'b11;

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_CHECK_IMM = 3'd2,
    S_SIM       = 3'd3,
    S_DONE      = 3'd4
  } state_t;

  state_t state, next_state;

  // Time counter (0-15)
  reg [3:0] time_cnt;

  // Current occupancy bitmasks
  reg [15:0] joe_cur;   // Joe positions at current time
  reg [15:0] fire_cur;  // Fire positions at current time
  reg [15:0] wall_mask; // Walls (static)

  // Next-step masks
  reg [15:0] joe_next;
  reg [15:0] fire_next;

  // Internal flags
  reg escape_now;        // Joe escapes at this step
  reg joe_dead_now;      // Joe burned at/after this step
  reg no_joe_next;       // Joe has no positions next step

  // Helper wires for combinational calculations
  integer idx;

  // Decode initial grid into masks
  function automatic [15:0] f_init_joe(input [15:0][1:0] g);
    integer i;
    reg [15:0] m;
    begin
      m = 16'b0;
      for (i = 0; i < 16; i = i + 1) begin
        if (g[i] == CELL_JOE)
          m[i] = 1'b1;
      end
      f_init_joe = m;
    end
  endfunction

  function automatic [15:0] f_init_fire(input [15:0][1:0] g);
    integer i;
    reg [15:0] m;
    begin
      m = 16'b0;
      for (i = 0; i < 16; i = i + 1) begin
        if (g[i] == CELL_FIRE)
          m[i] = 1'b1;
      end
      f_init_fire = m;
    end
  endfunction

  function automatic [15:0] f_init_wall(input [15:0][1:0] g);
    integer i;
    reg [15:0] m;
    begin
      m = 16'b0;
      for (i = 0; i < 16; i = i + 1) begin
        if (g[i] == CELL_WALL)
          m[i] = 1'b1;
      end
      f_init_wall = m;
    end
  endfunction

  // Check if any of Joe's positions are on the maze edge
  function automatic logic f_escape_edge(input [15:0] jm);
    begin
      f_escape_edge = |(jm & 16'b1111000010001111);
      // Edge indices mask (1-bits at indices 0,1,2,3,4,7,8,11,12,13,14,15)
      // Represented in bit[15:0] with bit index == cell index.
    end
  endfunction

  // Compute next fire positions (BFS spread to non-wall)
  function automatic [15:0] f_fire_next(
    input [15:0] fire_m,
    input [15:0] wall_m
  );
    reg [15:0] up, down, left, right;
    reg [15:0] neigh;
    begin
      // Vertical moves
      up   = (fire_m << 4);
      down = (fire_m >> 4);

      // Horizontal moves: prevent wrap between columns
      // Left: from col>0 only
      left = (fire_m & 16'b1110111011101110) >> 1;
      // Right: from col<3 only
      right = (fire_m & 16'b0111011101110111) << 1;

      neigh = up | down | left | right;
      // Fire occupies its neighbors unless wall
      f_fire_next = fire_m | (neigh & ~wall_m);
    end
  endfunction

  // Compute next Joe positions (move to open and not-on-fire cells)
  function automatic [15:0] f_joe_next(
    input [15:0] joe_m,
    input [15:0] wall_m,
    input [15:0] fire_n
  );
    reg [15:0] up, down, left, right;
    reg [15:0] cand;
    begin
      // Vertical moves
      up   = (joe_m << 4);
      down = (joe_m >> 4);

      // Horizontal moves: prevent wrap
      left  = (joe_m & 16'b1110111011101110) >> 1;
      right = (joe_m & 16'b0111011101110111) << 1;

      cand = up | down | left | right;
      // Remove walls and fire cells (Joe cannot move into or remain on fire)
      cand = cand & ~wall_m & ~fire_n;
      f_joe_next = cand;
    end
  endfunction

  // Synchronous state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      time_cnt     <= 4'd0;
      joe_cur      <= 16'b0;
      fire_cur     <= 16'b0;
      wall_mask    <= 16'b0;
      time_o       <= 4'd0;
      impossible_o <= 1'b0;
      done_o       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done_o       <= 1'b0;
          impossible_o <= 1'b0;
          time_o       <= 4'd0;
          if (start) begin
            // Latch initial grid into masks
            joe_cur   <= f_init_joe(grid_i);
            fire_cur  <= f_init_fire(grid_i);
            wall_mask <= f_init_wall(grid_i);
            time_cnt  <= 4'd0;
          end
        end

        S_INIT: begin
          // Nothing additional; move to immediate checks
        end

        S_CHECK_IMM: begin
          // Immediate outcome based on initial positions
          if (escape_now) begin
            time_o       <= 4'd0;
            impossible_o <= 1'b0;
            done_o       <= 1'b1;
          end else if (no_joe_next || joe_dead_now) begin
            time_o       <= 4'd0;
            impossible_o <= 1'b1;
            done_o       <= 1'b1;
          end else begin
            // Prepare for simulation loop: apply first step computed in comb
            joe_cur  <= joe_next;
            fire_cur <= fire_next;
            time_cnt <= 4'd1;
          end
        end

        S_SIM: begin
          // Update with next-step results
          joe_cur  <= joe_next;
          fire_cur <= fire_next;

          if (!done_o) begin
            time_cnt <= time_cnt + 4'd1;
          end

          // Latch outputs when finishing this cycle
          if (escape_now) begin
            time_o       <= time_cnt;
            impossible_o <= 1'b0;
            done_o       <= 1'b1;
          end else if (no_joe_next || joe_dead_now || (time_cnt == 4'd15)) begin
            // If Joe has no moves, burned, or exceeded max time
            time_o       <= time_cnt;
            impossible_o <= 1'b1;
            done_o       <= 1'b1;
          end
        end

        S_DONE: begin
          // Hold result until next start
          if (start) begin
            done_o       <= 1'b0;
            impossible_o <= 1'b0;
            time_o       <= 4'd0;
            joe_cur      <= f_init_joe(grid_i);
            fire_cur     <= f_init_fire(grid_i);
            wall_mask    <= f_init_wall(grid_i);
            time_cnt     <= 4'd0;
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Combinational next-state and step computation
  always @(*) begin
    // Default
    next_state  = state;
    joe_next    = 16'b0;
    fire_next   = fire_cur;
    escape_now  = 1'b0;
    joe_dead_now= 1'b0;
    no_joe_next = 1'b0;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        // From initialized masks, compute results for t=0 scenario
        fire_next   = fire_cur;

        // If initial Joe on edge -> immediate escape
        escape_now  = f_escape_edge(joe_cur);

        // Joe dead immediately if fire already in his cell
        joe_dead_now= |(joe_cur & fire_cur);

        // Also precompute one-step next positions for use if needed
        fire_next   = f_fire_next(fire_cur, wall_mask);
        joe_next    = f_joe_next(joe_cur, wall_mask, fire_next);
        no_joe_next = (joe_next == 16'b0);

        next_state  = S_CHECK_IMM;
      end

      S_CHECK_IMM: begin
        // Decisions already derived in sequential block via flags
        if (escape_now || no_joe_next || joe_dead_now)
          next_state = S_DONE;
        else
          next_state = S_SIM;
      end

      S_SIM: begin
        // One simulation minute per cycle:
        // 1) Fire spreads
        fire_next = f_fire_next(fire_cur, wall_mask);

        // 2) Joe moves to neighbors not on/into fire
        joe_next = f_joe_next(joe_cur, wall_mask, fire_next);

        // 3) Determine outcomes based on next positions
        no_joe_next = (joe_next == 16'b0);

        // Joe burning: any of his next cells already on fire after spread
        joe_dead_now = |(joe_next & fire_next);

        // Joe escape if any next Joe cell is on an edge and not on fire
        escape_now = f_escape_edge(joe_next & ~fire_next);

        // Advance or finish
        if (escape_now || no_joe_next || joe_dead_now || (time_cnt == 4'd15))
          next_state = S_DONE;
        else
          next_state = S_SIM;
      end

      S_DONE: begin
        if (start)
          next_state = S_INIT;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule