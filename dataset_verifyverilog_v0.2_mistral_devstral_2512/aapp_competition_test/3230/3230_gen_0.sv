module tram_explosion_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  output reg [7:0] char_addr,
  output reg [3:0] explosions,
  output reg done
);

  // Parameters
  localparam MAX_X = 8;
  localparam MAX_L = 8;
  localparam GRID_SIZE = 10;
  localparam GRID_ADDR_SIZE = 100;

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    READ_GRID,
    CALC_DISTANCES,
    RESOLVE_CONFLICTS,
    COUNT_EXPLOSIONS,
    FINISHED
  } state_t;

  // Internal signals
  state_t state, next_state;
  reg [6:0] load_idx;
  reg [3:0] x_count, l_count;
  reg [3:0] x_idx, l_idx;
  reg [3:0] conflict_idx;
  reg [7:0] min_dist;
  reg [3:0] target_seat_idx;
  reg [3:0] target_counts [0:MAX_L-1];
  reg [7:0] min_dist_for_L [0:MAX_L-1];
  reg [3:0] x_row [0:MAX_X-1], x_col [0:MAX_X-1];
  reg [3:0] l_row [0:MAX_L-1], l_col [0:MAX_L-1];
  reg [3:0] x_target [0:MAX_X-1];
  reg [7:0] x_dist [0:MAX_X-1];

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_idx <= 0;
      x_count <= 0;
      l_count <= 0;
      x_idx <= 0;
      l_idx <= 0;
      conflict_idx <= 0;
      min_dist <= 0;
      target_seat_idx <= 0;
      for (int i = 0; i < MAX_L; i++) begin
        target_counts[i] <= 0;
        min_dist_for_L[i] <= 0;
      end
      for (int i = 0; i < MAX_X; i++) begin
        x_row[i] <= 0;
        x_col[i] <= 0;
        x_target[i] <= 0;
        x_dist[i] <= 0;
      end
      for (int i = 0; i < MAX_L; i++) begin
        l_row[i] <= 0;
        l_col[i] <= 0;
      end
      explosions <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = READ_GRID;
      READ_GRID: if (load_idx == GRID_ADDR_SIZE - 1) next_state = CALC_DISTANCES;
      CALC_DISTANCES: if (x_idx == x_count && l_idx == 0) next_state = RESOLVE_CONFLICTS;
      RESOLVE_CONFLICTS: if (x_idx == x_count) next_state = COUNT_EXPLOSIONS;
      COUNT_EXPLOSIONS: if (conflict_idx == l_count) next_state = FINISHED;
      FINISHED: if (!start) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_addr <= 0;
    end else begin
      case (state)
        IDLE: char_addr <= 0;
        READ_GRID: char_addr <= load_idx;
        default: char_addr <= 0;
      endcase
    end
  end

  // READ_GRID state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_idx <= 0;
      x_count <= 0;
      l_count <= 0;
    end else if (state == READ_GRID) begin
      if (char_in == "X" && x_count < MAX_X) begin
        x_row[x_count] <= load_idx / GRID_SIZE;
        x_col[x_count] <= load_idx % GRID_SIZE;
        x_count <= x_count + 1;
      end else if (char_in == "L" && l_count < MAX_L) begin
        l_row[l_count] <= load_idx / GRID_SIZE;
        l_col[l_count] <= load_idx % GRID_SIZE;
        l_count <= l_count + 1;
      end
      if (load_idx < GRID_ADDR_SIZE - 1) begin
        load_idx <= load_idx + 1;
      end
    end
  end

  // CALC_DISTANCES state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_idx <= 0;
      l_idx <= 0;
      min_dist <= 0;
      target_seat_idx <= 0;
    end else if (state == CALC_DISTANCES) begin
      if (x_idx < x_count) begin
        if (l_idx < l_count) begin
          reg [7:0] row_diff = x_row[x_idx] - l_row[l_idx];
          reg [7:0] col_diff = x_col[x_idx] - l_col[l_idx];
          reg [7:0] dist_sq = row_diff * row_diff + col_diff * col_diff;
          if (l_idx == 0 || dist_sq < min_dist) begin
            min_dist <= dist_sq;
            target_seat_idx <= l_idx;
          end
          l_idx <= l_idx + 1;
        end else begin
          x_target[x_idx] <= target_seat_idx;
          x_dist[x_idx] <= min_dist;
          x_idx <= x_idx + 1;
          l_idx <= 0;
          min_dist <= 0;
          target_seat_idx <= 0;
        end
      end
    end
  end

  // RESOLVE_CONFLICTS state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_idx <= 0;
      for (int i = 0; i < MAX_L; i++) begin
        target_counts[i] <= 0;
        min_dist_for_L[i] <= 0;
      end
    end else if (state == RESOLVE_CONFLICTS) begin
      if (x_idx < x_count) begin
        reg [3:0] seat = x_target[x_idx];
        reg [7:0] dist = x_dist[x_idx];
        if (target_counts[seat] == 0) begin
          min_dist_for_L[seat] <= dist;
        end else if (dist < min_dist_for_L[seat]) begin
          min_dist_for_L[seat] <= dist;
        end
        target_counts[seat] <= target_counts[seat] + 1;
        x_idx <= x_idx + 1;
      end
    end
  end

  // COUNT_EXPLOSIONS state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      conflict_idx <= 0;
      explosions <= 0;
    end else if (state == COUNT_EXPLOSIONS) begin
      if (conflict_idx < l_count) begin
        if (target_counts[conflict_idx] > 1) begin
          reg [3:0] count = 0;
          for (int i = 0; i < x_count; i++) begin
            if (x_target[i] == conflict_idx && x_dist[i] == min_dist_for_L[conflict_idx]) begin
              count = count + 1;
            end
          end
          if (count > 1) begin
            explosions <= explosions + 1;
          end
        end
        conflict_idx <= conflict_idx + 1;
      end
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (state == FINISHED) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule