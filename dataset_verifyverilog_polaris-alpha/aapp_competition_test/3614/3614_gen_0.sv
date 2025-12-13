module grasshopper_path(
  input clk,
  input rst_n,
  input start,
  input [15:0] grid [0:15],
  input [1:0] init_row,
  input [1:0] init_col,
  output reg [3:0] max_flowers,
  output reg done
);

  // Internal state encoding
  localparam IDLE    = 2'b00;
  localparam INIT    = 2'b01;
  localparam EXPLORE = 2'b10;
  localparam DONE    = 2'b11;

  reg [1:0] state, next_state;

  // Internal grid storage (4x4)
  reg [15:0] grid_reg [0:3][0:3];

  // Stack for DFS path: positions and values
  reg [1:0] stack_row   [0:15];
  reg [1:0] stack_col   [0:15];
  reg [15:0] stack_val  [0:15];
  reg [2:0] stack_move_idx [0:15]; // which move index tried at this depth (0-7)

  reg [4:0] depth;           // current path length (1-16), 5 bits for safety
  reg [3:0] max_path_len;    // tracks maximum path length

  // Visited flags for 4x4 grid
  reg visited [0:3][0:3];

  // Signals for current top of stack
  reg [1:0] cur_row;
  reg [1:0] cur_col;
  reg [15:0] cur_val;
  reg [2:0] cur_move_idx;

  // Next-state control
  reg backtrack;
  reg push_next;
  reg [1:0] next_row;
  reg [1:0] next_col;
  reg [15:0] next_val;
  reg [2:0] next_move_idx;

  // Movement offsets (knight-like moves)
  function automatic [3:0] get_dr_dc;
    input [2:0] idx;
    reg signed [2:0] dr, dc;
    begin
      case (idx)
        3'd0: begin dr = -2; dc = -1; end
        3'd1: begin dr = -2; dc =  1; end
        3'd2: begin dr = -1; dc = -2; end
        3'd3: begin dr = -1; dc =  2; end
        3'd4: begin dr =  1; dc = -2; end
        3'd5: begin dr =  1; dc =  2; end
        3'd6: begin dr =  2; dc = -1; end
        3'd7: begin dr =  2; dc =  1; end
        default: begin dr = 0; dc = 0; end
      endcase
      get_dr_dc = {dr[1:0], dc[1:0]};
    end
  endfunction

  // Bounds check function
  function automatic is_in_bounds;
    input [1:0] r;
    input [1:0] c;
    begin
      is_in_bounds = (r < 4) && (c < 4);
    end
  endfunction

  // Sequential state and storage updates
  integer i, r, c;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      max_flowers  <= 4'd0;
      max_path_len <= 4'd0;
      done         <= 1'b0;
      depth        <= 5'd0;
      // clear visited
      for (r = 0; r < 4; r = r + 1) begin
        for (c = 0; c < 4; c = c + 1) begin
          visited[r][c] <= 1'b0;
          grid_reg[r][c] <= 16'd0;
        end
      end
      for (i = 0; i < 16; i = i + 1) begin
        stack_row[i]      <= 2'd0;
        stack_col[i]      <= 2'd0;
        stack_val[i]      <= 16'd0;
        stack_move_idx[i] <= 3'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done         <= 1'b0;
          max_path_len <= max_path_len; // keep
          if (start) begin
            // Load grid
            for (r = 0; r < 4; r = r + 1) begin
              for (c = 0; c < 4; c = c + 1) begin
                grid_reg[r][c] <= grid[r*4 + c];
                visited[r][c]  <= 1'b0;
              end
            end
            // Clear stack and depth; actual push happens in INIT
            for (i = 0; i < 16; i = i + 1) begin
              stack_row[i]      <= 2'd0;
              stack_col[i]      <= 2'd0;
              stack_val[i]      <= 16'd0;
              stack_move_idx[i] <= 3'd0;
            end
            depth        <= 5'd0;
            max_path_len <= 4'd0;
            max_flowers  <= 4'd0;
          end
        end

        INIT: begin
          // Initialize starting position on stack at depth 1
          stack_row[0]      <= init_row;
          stack_col[0]      <= init_col;
          stack_val[0]      <= grid_reg[init_row][init_col];
          stack_move_idx[0] <= 3'd0;
          visited[init_row][init_col] <= 1'b1;
          depth <= 5'd1;
          // Initialize max with at least 1
          max_path_len <= 4'd1;
          max_flowers  <= 4'd1;
        end

        EXPLORE: begin
          // Default: keep previous values, then override per control signals
          // Load current top-of-stack context
          if (depth != 0) begin
            cur_row      <= stack_row[depth-1];
            cur_col      <= stack_col[depth-1];
            cur_val      <= stack_val[depth-1];
            cur_move_idx <= stack_move_idx[depth-1];
          end

          if (backtrack) begin
            if (depth > 0) begin
              // Pop top element and clear visited
              visited[stack_row[depth-1]][stack_col[depth-1]] <= 1'b0;
              depth <= depth - 1'b1;
            end
          end else if (push_next) begin
            // Push new node onto stack
            stack_row[depth]      <= next_row;
            stack_col[depth]      <= next_col;
            stack_val[depth]      <= next_val;
            stack_move_idx[depth] <= 3'd0;
            visited[next_row][next_col] <= 1'b1;
            depth <= depth + 1'b1;
            // Update top's move index (parent already updated combinationally)
          end else if (depth != 0) begin
            // Only update move index for current top when searching next moves
            stack_move_idx[depth-1] <= next_move_idx;
          end

          // Update global maximum if needed
          if (depth > max_path_len) begin
            max_path_len <= (depth[3:0] != 4'd0) ? depth[3:0] : max_path_len;
            max_flowers  <= (depth[3:0] != 4'd0) ? depth[3:0] : max_flowers;
          end
        end

        DONE: begin
          done        <= 1'b1;
          max_flowers <= max_path_len;
        end

        default: begin
        end
      endcase
    end
  end

  // Combinational next_state and DFS exploration logic
  always @(*) begin
    next_state    = state;
    backtrack     = 1'b0;
    push_next     = 1'b0;
    next_row      = 2'd0;
    next_col      = 2'd0;
    next_val      = 16'd0;
    next_move_idx = 3'd0;

    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        // Move to exploration after initialization
        next_state = EXPLORE;
      end

      EXPLORE: begin
        if (depth == 0) begin
          // All paths explored
          next_state = DONE;
        end else begin
          // Get current node info from top of stack
          cur_row      = stack_row[depth-1];
          cur_col      = stack_col[depth-1];
          cur_val      = stack_val[depth-1];
          cur_move_idx = stack_move_idx[depth-1];

          // Try to find next valid move from current node
          if (cur_move_idx < 3'd8 && depth < 5'd16) begin
            // compute candidate based on current move index
            reg [3:0] dr_dc;
            reg signed [2:0] dr_s, dc_s;
            reg [2:0] mi;
            mi = cur_move_idx;
            dr_dc = get_dr_dc(mi);
            dr_s = { {1{dr_dc[3]}}, dr_dc[3:2] }; // sign-extend 2-bit to 3-bit
            dc_s = { {1{dr_dc[1]}}, dr_dc[1:0] };

            // candidate coordinates
            reg signed [3:0] r_s, c_s;
            r_s = $signed({1'b0, cur_row}) + dr_s;
            c_s = $signed({1'b0, cur_col}) + dc_s;

            // update move index for next attempt (default)
            next_move_idx = mi + 3'd1;

            if (r_s >= 0 && r_s < 4 && c_s >= 0 && c_s < 4) begin
              next_row = r_s[1:0];
              next_col = c_s[1:0];
              if (!visited[next_row][next_col]) begin
                next_val = grid_reg[next_row][next_col];
                if (next_val > cur_val) begin
                  // Valid move found: push this next position
                  push_next = 1'b1;
                end else begin
                  // Invalid by value; continue to next move index
                  backtrack = 1'b0;
                end
              end
            end

            // If not pushing, we'll simply update current node's move index
          end else begin
            // No more moves from this node or reached max depth, backtrack
            backtrack  = 1'b1;
          end
        end
      end

      DONE: begin
        // Wait here; could return to IDLE on new start if desired
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule