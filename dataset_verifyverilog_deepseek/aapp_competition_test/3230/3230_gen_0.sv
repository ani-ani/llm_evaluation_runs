module tram_explosion_counter (
  input clk,
  input rst_n,
  input start,
  input [1:0] rows,
  input [1:0] cols,
  input [15:0][1:0] grid,
  output reg [1:0] explosions,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    COMPUTE_DIST,
    FIND_MIN,
    CHECK_COLLISION,
    UPDATE_GRID
  } state_t;

  state_t current_state, next_state;
  reg [15:0][1:0] grid_reg;
  reg [15:0] active_X;
  reg [15:0] active_L;
  reg [15:0] next_active_X;
  reg [15:0] next_active_L;
  reg [1:0] explosion_count;
  reg [15:0][31:0] min_distance;
  reg [15:0][4:0] min_count;
  reg [15:0][15:0] is_min;
  reg collision_found;

  function [1:0] get_row;
    input [3:0] index;
    get_row = index >> 2;
  endfunction

  function [1:0] get_col;
    input [3:0] index;
    get_col = index[1:0];
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      grid_reg <= grid;
      active_X <= 16'h0;
      active_L <= 16'h0;
      explosions <= 2'h0;
      done <= 1'b0;
      for (int i = 0; i < 16; i++) begin
        if (grid[i] == 2'b01) active_X[i] <= 1'b1;
        if (grid[i] == 2'b10) active_L[i] <= 1'b1;
      end
    end else begin
      current_state <= next_state;
      if (current_state == COMPUTE_DIST) begin
        for (int i = 0; i < 16; i++) begin
          min_distance[i] <= 32'hFFFF_FFFF;
          min_count[i] <= 5'h0;
        end
        is_min <= 256'h0;
      end
      if (current_state == CHECK_COLLISION) begin
        explosion_count <= explosions;
        collision_found <= 1'b0;
      end
      if (current_state == UPDATE_GRID) begin
        active_X <= next_active_X;
        active_L <= next_active_L;
        if (collision_found) explosions <= explosion_count + 1;
      end
      done <= (next_state == IDLE && current_state != IDLE);
    end
  end

  always_comb begin
    next_state = current_state;
    next_active_X = active_X;
    next_active_L = active_L;
    case (current_state)
      IDLE: begin
        if (start) next_state = COMPUTE_DIST;
      end
      COMPUTE_DIST: begin
        next_state = FIND_MIN;
      end
      FIND_MIN: begin
        for (int l = 0; l < 16; l++) begin
          if (active_L[l]) begin
            for (int x = 0; x < 16; x++) begin
              if (active_X[x]) begin
                logic signed [1:0] row_l = get_row(l[3:0]);
                logic signed [1:0] col_l = get_col(l[3:0]);
                logic signed [1:0] row_x = get_row(x[3:0]);
                logic signed [1:0] col_x = get_col(x[3:0]);
                logic signed [17:0] dx = (row_l - row_x);
                logic signed [17:0] dy = (col_l - col_x);
                logic signed [31:0] dx_sq = (dx * dx) << 16;
                logic signed [31:0] dy_sq = (dy * dy) << 16;
                logic signed [31:0] dist = dx_sq + dy_sq;
                if (dist < min_distance[l]) begin
                  min_distance[l] = dist;
                  min_count[l] = 5'h1;
                  is_min[l][x] = 1'b1;
                end else if (dist == min_distance[l]) begin
                  min_count[l] = min_count[l] + 5'h1;
                  is_min[l][x] = 1'b1;
                end
              end
            end
          end
        end
        next_state = CHECK_COLLISION;
      end
      CHECK_COLLISION: begin
        collision_found = 1'b0;
        next_active_X = active_X;
        next_active_L = active_L;
        for (int l = 0; l < 16; l++) begin
          if (active_L[l] && (min_count[l] > 1)) begin
            collision_found = 1'b1;
            next_active_L[l] = 1'b0;
            for (int x = 0; x < 16; x++) begin
              if (is_min[l][x]) begin
                next_active_X[x] = 1'b0;
              end
            end
          end
        end
        next_state = UPDATE_GRID;
      end
      UPDATE_GRID: begin
        if ((|active_L) && (|active_X)) next_state = COMPUTE_DIST;
        else next_state = IDLE;
      end
    endcase
  end

endmodule