module jelly_raid (
  input clk,
  input rst_n,
  input start,
  input [2:0] start_row, start_col,
  input [2:0] target_row, target_col,
  input [7:0] map_data [0:7][0:7],
  input [2:0] m1_path [0:3],
  input [2:0] m2_path [0:3],
  output reg [7:0] min_turns,
  output reg possible
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTING,
    DONE
  } state_t;

  state_t state, next_state;

  // Turn counter
  reg [7:0] turn;

  // Reachable set (bitmask for each position)
  reg [7:0] reachable [0:7][0:7];
  reg [7:0] next_reachable [0:7][0:7];

  // Master positions
  reg [2:0] m1_pos, m2_pos;
  reg [1:0] m1_dir, m2_dir; // 0=forward, 1=backward

  // Helper functions
  function logic is_spotted;
    input [2:0] row, col;
    input [2:0] m_row, m_col;
    begin
      if (row == m_row) begin
        if (col > m_col) begin
          for (int i = m_col + 1; i < col; i = i + 1) begin
            if (map_data[row][i] == 8'h23) return 0; // '#' blocks
          end
        end else if (col < m_col) begin
          for (int i = col + 1; i < m_row; i = i + 1) begin
            if (map_data[row][i] == 8'h23) return 0;
          end
        end else return 1; // same position
      end else if (col == m_col) begin
        if (row > m_row) begin
          for (int i = m_row + 1; i < row; i = i + 1) begin
            if (map_data[i][col] == 8'h23) return 0;
          end
        end else if (row < m_row) begin
          for (int i = row + 1; i < m_row; i = i + 1) begin
            if (map_data[i][col] == 8'h23) return 0;
          end
        end else return 1;
      end
      return 0;
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      turn <= 0;
      min_turns <= 0;
      possible <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        for (int j = 0; j < 8; j = j + 1) begin
          reachable[i][j] <= 0;
        end
      end
      m1_dir <= 0;
      m2_dir <= 0;
    end else begin
      state <= next_state;
      if (state == COMPUTING) begin
        turn <= turn + 1;
        // Update master positions
        if (m1_dir == 0) begin
          if (m1_pos == m1_path[3]) m1_dir <= 1;
          else m1_pos <= m1_path[m1_pos + 1];
        end else begin
          if (m1_pos == m1_path[0]) m1_dir <= 0;
          else m1_pos <= m1_path[m1_pos - 1];
        end
        if (m2_dir == 0) begin
          if (m2_pos == m2_path[3]) m2_dir <= 1;
          else m2_pos <= m2_path[m2_pos + 1];
        end else begin
          if (m2_pos == m2_path[0]) m2_dir <= 0;
          else m2_pos <= m2_path[m2_pos - 1];
        end
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COMPUTING;
      end
      COMPUTING: begin
        if (turn == 8'd255 || possible) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Reachable set processing
  always @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i = i + 1) begin
        for (int j = 0; j < 8; j = j + 1) begin
          reachable[i][j] <= 0;
          next_reachable[i][j] <= 0;
        end
      end
    end else if (state == COMPUTING) begin
      // Check if target is in reachable set
      if (reachable[target_row][target_col]) begin
        min_turns <= turn;
        possible <= 1;
      end

      // Prune reachable set (remove spotted positions)
      for (int i = 0; i < 8; i = i + 1) begin
        for (int j = 0; j < 8; j = j + 1) begin
          if (reachable[i][j] && (is_spotted(i, j, m1_pos[2:0], m1_pos[2:0]) || is_spotted(i, j, m2_pos[2:0], m2_pos[2:0]))) begin
            reachable[i][j] <= 0;
          end
        end
      end

      // Generate next_reachable set
      for (int i = 0; i < 8; i = i + 1) begin
        for (int j = 0; j < 8; j = j + 1) begin
          if (reachable[i][j]) begin
            // Stay
            if (map_data[i][j] == 0) next_reachable[i][j] <= 1;
            // Up
            if (i > 0 && map_data[i-1][j] == 0) next_reachable[i-1][j] <= 1;
            // Down
            if (i < 7 && map_data[i+1][j] == 0) next_reachable[i+1][j] <= 1;
            // Left
            if (j > 0 && map_data[i][j-1] == 0) next_reachable[i][j-1] <= 1;
            // Right
            if (j < 7 && map_data[i][j+1] == 0) next_reachable[i][j+1] <= 1;
          end
        end
      end

      // Update reachable set
      for (int i = 0; i < 8; i = i + 1) begin
        for (int j = 0; j < 8; j = j + 1) begin
          reachable[i][j] <= next_reachable[i][j];
          next_reachable[i][j] <= 0;
        end
      end
    end
  end

  // Initialize reachable set on start
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled above
    end else if (state == IDLE && start) begin
      for (int i = 0; i < 8; i = i + 1) begin
        for (int j = 0; j < 8; j = j + 1) begin
          reachable[i][j] <= 0;
        end
      end
      reachable[start_row][start_col] <= 1;
      turn <= 0;
      min_turns <= 0;
      possible <= 0;
      m1_pos <= m1_path[0];
      m2_pos <= m2_path[0];
      m1_dir <= 0;
      m2_dir <= 0;
    end
  end

endmodule