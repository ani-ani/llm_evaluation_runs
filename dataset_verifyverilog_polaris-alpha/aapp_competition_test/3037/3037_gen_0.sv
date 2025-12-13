module turtle_tracker(
  input clk,
  input rst_n,
  input start,
  input [15:0] target_grid,
  input [7:0] cmd_0, cmd_1, cmd_2, cmd_3, cmd_4, cmd_5, cmd_6, cmd_7,
  input [2:0] num_cmds,
  output reg [6:0] min_time,
  output reg [6:0] max_time,
  output reg done,
  output reg valid_result
);

  // Parameters
  localparam GRID_SIZE     = 4;
  localparam NUM_CELLS     = 16;
  localparam MAX_TIME_VAL  = 7'd120;
  localparam FIRST_INIT    = 7'd127; // sentinel > MAX_TIME_VAL for unmarked
  localparam LAST_INIT     = 7'd0;   // 0 for unmarked

  // State machine
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_RUN_STEP  = 3'd1,
    S_NEXT_CMD  = 3'd2,
    S_ANALYZE_0 = 3'd3,
    S_ANALYZE_1 = 3'd4,
    S_DONE      = 3'd5
  } state_t;

  state_t state, next_state;

  // Command storage
  reg [7:0] cmds [0:7];

  // Indices and counters
  reg [2:0] cmd_idx;          // which command (0-7)
  reg [3:0] step_in_cmd;      // remaining steps in current command (0-15)
  reg [6:0] time_ctr;         // global time (0..120)

  // Turtle position
  reg [1:0] row;
  reg [1:0] col;

  // Per-cell timing
  reg [6:0] first_time [0:NUM_CELLS-1];
  reg [6:0] last_time  [0:NUM_CELLS-1];

  // Analysis accumulators
  reg [4:0] cell_idx;         // 0..15
  reg [6:0] min_t_acc;        // for earliest common dry time (max of first)
  reg [6:0] max_t_acc;        // for latest common dry time (min of last)
  reg       any_miss;         // flag if any target cell never marked

  // Helper: get command from index
  function automatic [7:0] get_cmd(input [2:0] idx);
    case (idx)
      3'd0: get_cmd = cmd_0;
      3'd1: get_cmd = cmd_1;
      3'd2: get_cmd = cmd_2;
      3'd3: get_cmd = cmd_3;
      3'd4: get_cmd = cmd_4;
      3'd5: get_cmd = cmd_5;
      3'd6: get_cmd = cmd_6;
      3'd7: get_cmd = cmd_7;
      default: get_cmd = 8'd0;
    endcase
  endfunction

  // Helper: encode (row,col) -> index
  function automatic [4:0] rc2idx(input [1:0] r, input [1:0] c);
    rc2idx = r*GRID_SIZE + c;
  endfunction

  // Clamp distance so turtle never leaves grid
  function automatic [3:0] clamp_dist(
    input [1:0] dir,
    input [3:0] dist,
    input [1:0] r,
    input [1:0] c
  );
    reg [3:0] max_d;
    begin
      case (dir)
        2'b00: max_d = r;              // up
        2'b01: max_d = (GRID_SIZE-1) - r; // down
        2'b10: max_d = c;              // left
        2'b11: max_d = (GRID_SIZE-1) - c; // right
        default: max_d = 4'd0;
      endcase
      clamp_dist = (dist > max_d) ? max_d : dist;
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_RUN_STEP;
      end

      S_RUN_STEP: begin
        // If no commands or all commands processed and no remaining steps, go analyze
        if ((num_cmds == 3'd0) ||
            ((cmd_idx == num_cmds) && (step_in_cmd == 4'd0))) begin
          next_state = S_ANALYZE_0;
        end else if (step_in_cmd == 4'd0) begin
          next_state = S_NEXT_CMD;
        end else begin
          next_state = S_RUN_STEP; // continue stepping
        end
      end

      S_NEXT_CMD: begin
        // After loading next command parameters, go back to stepping
        next_state = S_RUN_STEP;
      end

      S_ANALYZE_0: begin
        next_state = S_ANALYZE_1;
      end

      S_ANALYZE_1: begin
        next_state = S_DONE;
      end

      S_DONE: begin
        if (!start) next_state = S_IDLE; // wait for start deassert then ready
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      done          <= 1'b0;
      valid_result  <= 1'b0;
      min_time      <= 7'd0;
      max_time      <= 7'd0;
      time_ctr      <= 7'd0;
      cmd_idx       <= 3'd0;
      step_in_cmd   <= 4'd0;
      row           <= 2'd3;  // bottom-left (row=3)
      col           <= 2'd0;  // bottom-left (col=0)
      cell_idx      <= 5'd0;
      min_t_acc     <= 7'd0;
      max_t_acc     <= MAX_TIME_VAL;
      any_miss      <= 1'b0;
      // init per-cell
      for (i = 0; i < NUM_CELLS; i = i + 1) begin
        first_time[i] <= FIRST_INIT;
        last_time[i]  <= LAST_INIT;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done         <= 1'b0;
          valid_result <= 1'b0;
          if (start) begin
            // Initialize for new run
            time_ctr    <= 7'd0;
            cmd_idx     <= 3'd0;
            step_in_cmd <= 4'd0;
            row         <= 2'd3;
            col         <= 2'd0;
            cell_idx    <= 5'd0;
            min_t_acc   <= 7'd0;          // for max of first times
            max_t_acc   <= MAX_TIME_VAL;  // for min of last times
            any_miss    <= 1'b0;

            // Latch commands into array (optional, for uniform access)
            cmds[0] <= cmd_0;
            cmds[1] <= cmd_1;
            cmds[2] <= cmd_2;
            cmds[3] <= cmd_3;
            cmds[4] <= cmd_4;
            cmds[5] <= cmd_5;
            cmds[6] <= cmd_6;
            cmds[7] <= cmd_7;

            // Clear per-cell times
            for (i = 0; i < NUM_CELLS; i = i + 1) begin
              first_time[i] <= FIRST_INIT;
              last_time[i]  <= LAST_INIT;
            end
            // Mark starting cell at t=0
            begin
              integer idx0;
              idx0 = rc2idx(2'd3, 2'd0);
              first_time[idx0] <= 7'd0;
              last_time[idx0]  <= 7'd0;
            end
          end
        end

        S_RUN_STEP: begin
          // Check if we should move to analysis or next command will be handled by next_state
          if ((num_cmds == 3'd0) || ((cmd_idx == num_cmds) && (step_in_cmd == 4'd0))) begin
            // no more stepping, prep for analysis
            cell_idx    <= 5'd0;
            min_t_acc   <= 7'd0;
            max_t_acc   <= MAX_TIME_VAL;
            any_miss    <= 1'b0;
          end else begin
            // If need to load a new command (handled in S_NEXT_CMD), nothing here
            if (step_in_cmd != 4'd0) begin
              // Perform one movement step according to current command
              // Extract direction from stored command
              // We use cmds[cmd_idx] which must have been set in S_NEXT_CMD or S_IDLE
              reg [1:0] dir;
              reg [4:0] idx;
              dir = cmds[cmd_idx][2:1];

              // Advance time
              time_ctr <= time_ctr + 7'd1;

              // Move position by 1 step in direction (already ensured we don't exceed bounds via clamp)
              case (dir)
                2'b00: if (row > 0)        row <= row - 2'd1; // up
                2'b01: if (row < 3)        row <= row + 2'd1; // down
                2'b10: if (col > 0)        col <= col - 2'd1; // left
                2'b11: if (col < 3)        col <= col + 2'd1; // right
                default: ;
              endcase

              // Mark the new cell at current (updated) row/col with new time
              idx = rc2idx(row, col);
              if (first_time[idx] == FIRST_INIT) begin
                first_time[idx] <= time_ctr + 7'd1; // time after increment
              end
              last_time[idx] <= time_ctr + 7'd1;

              // decrement remaining steps in this command
              step_in_cmd <= step_in_cmd - 4'd1;
            end
          end
        end

        S_NEXT_CMD: begin
          if (cmd_idx < num_cmds) begin
            reg [7:0] cmd;
            reg [1:0] dir;
            reg [3:0] dist_raw;
            reg [3:0] dist_clamped;
            cmd          = get_cmd(cmd_idx);
            dir          = cmd[2:1];
            dist_raw     = cmd[7:4];
            dist_clamped = clamp_dist(dir, dist_raw, row, col);
            cmds[cmd_idx] <= {dist_clamped, cmd[3:0]}; // store clamped distance with same low bits
            step_in_cmd   <= dist_clamped;
            cmd_idx       <= cmd_idx + 3'd1;
          end
        end

        S_ANALYZE_0: begin
          // Scan all cells to compute min_time and max_time window
          // min_time = max(first_time) over target '#' cells
          // max_time = min(last_time)  over target '#' cells
          // If any required cell never marked, flag miss
          min_t_acc <= 7'd0;
          max_t_acc <= MAX_TIME_VAL;
          any_miss  <= 1'b0;
          for (i = 0; i < NUM_CELLS; i = i + 1) begin
            if (target_grid[i]) begin
              if (first_time[i] == FIRST_INIT) begin
                any_miss <= 1'b1;
              end else begin
                if (first_time[i] > min_t_acc) min_t_acc <= first_time[i];
                if (last_time[i]  < max_t_acc) max_t_acc <= last_time[i];
              end
            end
          end
        end

        S_ANALYZE_1: begin
          // Finalize results based on accumulators
          if (any_miss || (min_t_acc > max_t_acc)) begin
            valid_result <= 1'b0;
            min_time     <= 7'h7F; // -1 encoded as all 1s (7'b1111111)
            max_time     <= 7'h7F;
          end else begin
            valid_result <= 1'b1;
            min_time     <= min_t_acc;
            max_time     <= max_t_acc;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // Hold results until next start (handled in S_IDLE)
        end

        default: ;
      endcase
    end
  end

endmodule