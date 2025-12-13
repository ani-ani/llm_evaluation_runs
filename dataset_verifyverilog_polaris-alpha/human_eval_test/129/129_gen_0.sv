module min_path (
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] grid [0:3][0:3],
  input  [3:0] k,
  output reg [63:0] path,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    INIT        = 3'd1,
    SEARCH      = 3'd2,
    BACKTRACK   = 3'd3,
    COMPARE     = 3'd4,
    UPDATE_PATH = 3'd5,
    DONE_STATE  = 3'd6
  } state_t;

  state_t state, next_state;

  // Internal signals
  reg [3:0] k_reg;            // latched k
  reg [3:0] best_path [0:15]; // current best path (values)
  reg       best_valid;       // indicates best_path is valid

  // DFS stack
  // depth ranges from 0 to k_reg-1 (inclusive)
  reg [4:0] depth;            // supports up to 16

  // For each depth: row, col, value, and next direction to try
  reg [1:0] stack_row   [0:15];
  reg [1:0] stack_col   [0:15];
  reg [3:0] stack_val   [0:15];
  reg [2:0] next_dir    [0:15]; // 0..3 neighbors, 4 = done

  // Visited mask for values 1..16 (indexed 0..15)
  reg [15:0] visited;

  // Compare indices
  reg [4:0] cmp_idx;
  reg       cmp_less;
  reg       cmp_done;

  // Helper wires
  wire [3:0] cur_k = k_reg;

  // Functions to translate and access grid
  function automatic [3:0] get_grid_val(input [1:0] r, input [1:0] c);
    get_grid_val = grid[r][c];
  endfunction

  // Get neighbor (row, col) based on direction
  // dir: 0=up, 1=down, 2=left, 3=right
  function automatic bit get_neighbor(
    input [1:0] in_r,
    input [1:0] in_c,
    input [2:0] dir,
    output [1:0] out_r,
    output [1:0] out_c
  );
    bit valid;
    reg [1:0] nr;
    reg [1:0] nc;
    nr = in_r;
    nc = in_c;
    case (dir)
      3'd0: begin // up
        if (in_r > 0) nr = in_r - 1; else valid = 0;
      end
      3'd1: begin // down
        if (in_r < 3) nr = in_r + 1; else valid = 0;
      end
      3'd2: begin // left
        if (in_c > 0) nc = in_c - 1; else valid = 0;
      end
      3'd3: begin // right
        if (in_c < 3) nc = in_c + 1; else valid = 0;
      end
      default: valid = 0;
    endcase

    if (dir <= 3) begin
      // default valid=1, overridden above when out of bounds
      if (dir == 0 || dir == 1 || dir == 2 || dir == 3) begin
        if (!((dir == 0 && in_r == 0) ||
              (dir == 1 && in_r == 3) ||
              (dir == 2 && in_c == 0) ||
              (dir == 3 && in_c == 3))) begin
          valid = 1;
        end
      end
    end

    out_r = nr;
    out_c = nc;
    get_neighbor = valid;
  endfunction

  // Sequential state/regs
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      done       <= 1'b0;
      path       <= 64'd0;
      best_valid <= 1'b0;
      visited    <= 16'd0;
      depth      <= 5'd0;
      k_reg      <= 4'd0;
      for (i = 0; i < 16; i = i + 1) begin
        best_path[i] <= 4'd0;
        stack_row[i] <= 2'd0;
        stack_col[i] <= 2'd0;
        stack_val[i] <= 4'd0;
        next_dir[i]  <= 3'd0;
      end
      cmp_idx  <= 5'd0;
      cmp_less <= 1'b0;
      cmp_done <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            k_reg      <= k;
            best_valid <= 1'b0;
            visited    <= 16'd0;
            depth      <= 5'd0;
            // Initialize starting position at (0,0)
            stack_row[0] <= 2'd0;
            stack_col[0] <= 2'd0;
            stack_val[0] <= get_grid_val(2'd0, 2'd0);
            next_dir[0]  <= 3'd0;
            // Mark visited
            visited[get_grid_val(2'd0,2'd0) - 1] <= 1'b1;
          end
        end

        INIT: begin
          // Not used separately; kept for extensibility
        end

        SEARCH: begin
          // If we reached required length, go to COMPARE
          if (depth + 1 == cur_k) begin
            cmp_idx  <= 5'd0;
            cmp_less <= 1'b0;
            cmp_done <= 1'b0;
          end else begin
            // Try next neighbor from current node
            if (next_dir[depth] < 4) begin
              reg [1:0] nr;
              reg [1:0] nc;
              bit n_valid;
              reg [3:0] v;

              n_valid = get_neighbor(stack_row[depth], stack_col[depth], next_dir[depth], nr, nc);

              if (n_valid) begin
                v = get_grid_val(nr, nc);
                if (!visited[v - 1]) begin
                  // Choose this neighbor: push to stack
                  depth <= depth + 1'b1;
                  stack_row[depth + 1'b1] <= nr;
                  stack_col[depth + 1'b1] <= nc;
                  stack_val[depth + 1'b1] <= v;
                  next_dir[depth + 1'b1]  <= 3'd0;
                  visited[v - 1]          <= 1'b1;
                end
              end

              // Move to next direction for current depth
              next_dir[depth] <= next_dir[depth] + 1'b1;
            end
          end
        end

        BACKTRACK: begin
          // Backtrack until a level with remaining directions or stack empty
          if (depth == 0 && next_dir[0] >= 4) begin
            // All complete
          end else begin
            if (depth > 0 && next_dir[depth] >= 4) begin
              // Unvisit current node and pop
              visited[stack_val[depth] - 1] <= 1'b0;
              depth <= depth - 1'b1;
            end
          end
        end

        COMPARE: begin
          // Lex compare current stack_val[0..k_reg-1] vs best_path
          if (!best_valid) begin
            // No best yet; current is best by default
            cmp_less <= 1'b1;
            cmp_done <= 1'b1;
          end else if (!cmp_done) begin
            if (cmp_idx < cur_k) begin
              if (stack_val[cmp_idx] < best_path[cmp_idx]) begin
                cmp_less <= 1'b1;
                cmp_done <= 1'b1;
              end else if (stack_val[cmp_idx] > best_path[cmp_idx]) begin
                cmp_less <= 1'b0;
                cmp_done <= 1'b1;
              end else begin
                cmp_idx <= cmp_idx + 1'b1;
              end
            end else begin
              // All equal (should not happen due to uniqueness), treat as not less
              cmp_less <= 1'b0;
              cmp_done <= 1'b1;
            end
          end
        end

        UPDATE_PATH: begin
          // Update best_path from current stack
          for (i = 0; i < 16; i = i + 1) begin
            if (i < cur_k)
              best_path[i] <= stack_val[i];
            else
              best_path[i] <= 4'd0;
          end
          best_valid <= 1'b1;
        end

        DONE_STATE: begin
          done <= 1'b1;
          // Pack best_path into 64-bit path, least recent (index 0) in LSBs
          path <= 64'd0;
          for (i = 0; i < 16; i = i + 1) begin
            path[(4*i)+3 -: 4] <= best_path[i];
          end
        end

        default: ;
      endcase
    end
  end

  // Next-state logic (combinational)
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = SEARCH;
      end

      SEARCH: begin
        if (depth + 1 == cur_k) begin
          // Completed a path
          next_state = COMPARE;
        end else if (next_dir[depth] >= 4) begin
          // No more neighbors at current depth
          if (depth == 0)
            next_state = DONE_STATE;
          else
            next_state = BACKTRACK;
        end else begin
          // Continue exploring
          next_state = SEARCH;
        end
      end

      BACKTRACK: begin
        if (depth == 0 && next_dir[0] >= 4) begin
          next_state = DONE_STATE;
        end else begin
          // After popping, decide whether to search more or backtrack further
          if (depth > 0 && next_dir[depth] < 4)
            next_state = SEARCH;
          else
            next_state = BACKTRACK;
        end
      end

      COMPARE: begin
        if (cmp_done) begin
          if (cmp_less)
            next_state = UPDATE_PATH;
          else
            next_state = ( (depth == 0 && next_dir[0] >= 4) ? DONE_STATE : BACKTRACK );
        end else begin
          next_state = COMPARE;
        end
      end

      UPDATE_PATH: begin
        next_state = ( (depth == 0 && next_dir[0] >= 4) ? DONE_STATE : BACKTRACK );
      end

      DONE_STATE: begin
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE_STATE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule