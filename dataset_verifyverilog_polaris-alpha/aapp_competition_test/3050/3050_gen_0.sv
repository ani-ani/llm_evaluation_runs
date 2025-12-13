module gl_bot_tracker(
  input clk,                   // clock signal
  input rst_n,                 // active-low reset
  input start,                 // pulse high to start simulation
  input [63:0] grid_data,      // 64-bit grid [row][col]: 1=passable, 0=impassable
  input [63:0] cmd_str,        // flattened command string (8 chars max, 8 bits per char)
  input [2:0] grid_size,       // actual grid size (3 <= size <= 8)
  input [2:0] start_row,       // initial robot row (3 bits for 0-7)
  input [2:0] start_col,       // initial robot column (3 bits for 0-7)
  output reg [5:0] result_x,   // cycle length (1-64) or 1 (finite trail)
  output reg done              // high when computation complete
);

  // State machine
  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    SIMULATE  = 2'b01,
    DONE      = 2'b10
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [2:0]  cur_row, cur_col;          // current position (0-7)
  reg [2:0]  next_row, next_col;
  reg [2:0]  cmd_idx;                   // 0-7 command index
  reg [2:0]  next_cmd_idx;
  reg [5:0]  step_cnt;                  // 0-63 steps
  reg [2:0]  cmd_len;                   // command string length (1-8)
  reg        started;                   // latch start pulse

  // Visited state tracking: use small CAM
  // Up to 64 recorded states: {row[2:0], col[2:0], cmd_idx[2:0]} and step index
  reg [2:0] vis_row   [0:63];
  reg [2:0] vis_col   [0:63];
  reg [2:0] vis_cmd   [0:63];
  reg [5:0] vis_step  [0:63];
  reg       vis_valid [0:63];

  // Wires for cycle detection
  reg        match_found;
  reg [5:0]  match_prev_step;

  // Command decoding
  function automatic [7:0] get_cmd_char(input [63:0] s, input [2:0] idx);
    get_cmd_char = s[{idx,3'b000} +: 8];
  endfunction

  // Compute command length from cmd_str assuming null-terminated or full-length if no 0
  function automatic [2:0] calc_cmd_len(input [63:0] s);
    integer i;
    reg [2:0] len;
    reg [7:0] ch;
    begin
      len = 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        ch = s[{i[2:0],3'b000} +: 8];
        if (ch != 8'd0 && len == i[2:0]) begin
          len = len + 3'd1;
        end
      end
      if (len == 3'd0) len = 3'd1; // ensure at least one command
      calc_cmd_len = len;
    end
  endfunction

  // Grid access: grid_data indexed as [row][col], row-major: bit = row*8+col
  function automatic bit cell_passable(
    input [63:0] g,
    input [2:0]  r,
    input [2:0]  c
  );
    cell_passable = g[{r,3'b000} + c];
  endfunction

  // Boundary check using grid_size
  function automatic bit in_bounds(
    input [2:0] r,
    input [2:0] c,
    input [2:0] size
  );
    in_bounds = (r < size) && (c < size);
  endfunction

  // Next position calculation based on command and grid
  function automatic void calc_next_pos(
    input  [2:0] cur_r,
    input  [2:0] cur_c,
    input  [7:0] cmd,
    input  [2:0] size,
    input  [63:0] g,
    output [2:0] out_r,
    output [2:0] out_c
  );
    reg [2:0] nr, nc;
    begin
      nr = cur_r;
      nc = cur_c;
      case (cmd)
        8'h3C: begin // '<'
          if (cur_c > 0) begin
            nc = cur_c - 3'd1;
            if (!in_bounds(cur_r, nc, size) || !cell_passable(g, cur_r, nc)) begin
              nc = cur_c;
            end
          end
        end
        8'h3E: begin // '>'
          if (cur_c + 3'd1 < size) begin
            nc = cur_c + 3'd1;
            if (!cell_passable(g, cur_r, nc)) begin
              nc = cur_c;
            end
          end
        end
        8'h5E: begin // '^'
          if (cur_r > 0) begin
            nr = cur_r - 3'd1;
            if (!in_bounds(nr, cur_c, size) || !cell_passable(g, nr, cur_c)) begin
              nr = cur_r;
            end
          end
        end
        8'h76: begin // 'v'
          if (cur_r + 3'd1 < size) begin
            nr = cur_r + 3'd1;
            if (!cell_passable(g, nr, cur_c)) begin
              nr = cur_r;
            end
          end
        end
        default: begin
          // no move for unrecognized
        end
      endcase
      out_r = nr;
      out_c = nc;
    end
  endfunction

  // Sequential logic: state, counters, position, visited table
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cur_row    <= 3'd0;
      cur_col    <= 3'd0;
      cmd_idx    <= 3'd0;
      step_cnt   <= 6'd0;
      cmd_len    <= 3'd1;
      result_x   <= 6'd0;
      done       <= 1'b0;
      started    <= 1'b0;
      for (i = 0; i < 64; i = i + 1) begin
        vis_valid[i] <= 1'b0;
        vis_row[i]   <= 3'd0;
        vis_col[i]   <= 3'd0;
        vis_cmd[i]   <= 3'd0;
        vis_step[i]  <= 6'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start && !started) begin
            started  <= 1'b1;
            cmd_len  <= calc_cmd_len(cmd_str);
            cur_row  <= start_row;
            cur_col  <= start_col;
            cmd_idx  <= 3'd0;
            step_cnt <= 6'd0;
            result_x <= 6'd0;
            for (i = 0; i < 64; i = i + 1) begin
              vis_valid[i] <= 1'b0;
              vis_row[i]   <= 3'd0;
              vis_col[i]   <= 3'd0;
              vis_cmd[i]   <= 3'd0;
              vis_step[i]  <= 6'd0;
            end
          end else if (!start) begin
            started <= 1'b0;
          end
        end

        SIMULATE: begin
          // Write current state into visited table at index step_cnt
          vis_valid[step_cnt] <= 1'b1;
          vis_row[step_cnt]   <= cur_row;
          vis_col[step_cnt]   <= cur_col;
          vis_cmd[step_cnt]   <= cmd_idx;
          vis_step[step_cnt]  <= step_cnt;

          // Advance step counter
          step_cnt <= step_cnt + 6'd1;

          // Update position and cmd index computed combinationally
          cur_row <= next_row;
          cur_col <= next_col;
          cmd_idx <= next_cmd_idx;

          // When finishing, result_x assigned in next_state logic
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            started <= 1'b0;
          end
        end
      endcase
    end
  end

  // Combinational: next_state, movement, cycle / finite detection
  always @* begin
    next_state      = state;
    match_found     = 1'b0;
    match_prev_step = 6'd0;

    // Defaults for next position
    next_row     = cur_row;
    next_col     = cur_col;
    next_cmd_idx = cmd_idx;

    case (state)
      IDLE: begin
        if (start && !started) begin
          next_state = SIMULATE;
        end
      end

      SIMULATE: begin
        // 1) Compute next command index
        if (cmd_len != 3'd0) begin
          if (cmd_idx + 3'd1 >= cmd_len)
            next_cmd_idx = 3'd0;
          else
            next_cmd_idx = cmd_idx + 3'd1;
        end else begin
          next_cmd_idx = 3'd0;
        end

        // 2) Decode current command and compute tentative next position
        begin
          reg [7:0] cur_cmd;
          cur_cmd = get_cmd_char(cmd_str, cmd_idx);
          calc_next_pos(cur_row, cur_col, cur_cmd, grid_size, grid_data, next_row, next_col);
        end

        // 3) Detect cycle: search previous states for (next_row, next_col, next_cmd_idx)
        begin
          integer j;
          for (j = 0; j < 64; j = j + 1) begin
            if (vis_valid[j] && !match_found) begin
              if (vis_row[j] == next_row && vis_col[j] == next_col && vis_cmd[j] == next_cmd_idx) begin
                match_found     = 1'b1;
                match_prev_step = vis_step[j];
              end
            end
          end
        end

        // 4) Determine termination
        if (match_found) begin
          // Cycle detected: length = (current_step + 1) - previous_step
          // step_cnt is current index for this step; after increment it becomes step_cnt+1
          // But combinationally we still see old step_cnt; cycle length = (step_cnt + 1) - match_prev_step
          result_x   = (step_cnt + 6'd1) - match_prev_step;
          next_state = DONE;
        end else if (step_cnt == 6'd63) begin
          // Reached 64 steps without cycle: finite trail
          result_x   = 6'd1;
          next_state = DONE;
        end else begin
          // Continue simulation
          next_state = SIMULATE;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule