module onion_protect(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_onions,
  input [3:0] num_posts,
  input [3:0] select_count,
  input [15:0] onion_x[0:7],
  input [15:0] onion_y[0:7],
  input [15:0] post_x[0:7],
  input [15:0] post_y[0:7],
  output reg [3:0] max_protected,
  output reg done
);

  typedef enum {IDLE, COMB_GEN, HULL_GEN, POINT_CHECK, UPDATE_MAX, DONE} state_t;
  state_t current_state, next_state;

  // Combination generator
  reg [3:0] combo[0:3]; // Supports K up to 4
  reg combo_valid;
  reg [3:0] combo_count;

  // Convex hull storage
  reg [15:0] hull_x[0:3];
  reg [15:0] hull_y[0:3];
  reg [2:0] hull_size;
  reg [3:0] post_idx[0:3];

  // Counting registers
  reg [3:0] protected_count;
  reg [3:0] onion_idx;
  reg [3:0] current_max;

  // Internal control signals
  wire [3:0] m_choose_k;
  reg combo_complete;
  reg hull_complete;
  reg count_complete;
  reg last_combo;

  // Combination counter math (3 or 4 choose)
  assign m_choose_k = (select_count == 4) ? (num_posts*(num_posts-1)*(num_posts-2)*(num_posts-3))/24 :
                      (num_posts*(num_posts-1)*(num_posts-2))/6;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_protected <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COMB_GEN;
      end
      
      COMB_GEN: begin
        if (combo_valid) next_state = HULL_GEN;
        else if (last_combo && !combo_valid) next_state = DONE;
      end
      
      HULL_GEN: begin
        if (hull_complete) next_state = POINT_CHECK;
      end
      
      POINT_CHECK: begin
        if (count_complete) next_state = UPDATE_MAX;
      end
      
      UPDATE_MAX: begin
        next_state = COMB_GEN;
      end
      
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Combination generator logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0; i<4; i++) combo[i] <= 0;
      combo_valid <= 0;
      combo_complete <= 0;
      last_combo <= 0;
    end else begin
      if (current_state == IDLE && start) begin
        // Initialize first combination
        combo[0] <= 0;
        combo[1] <= 1;
        combo[2] <= 2;
        if (select_count == 4) combo[3] <= 3;
        combo_valid <= 1;
        combo_complete <= 0;
        last_combo <= 0;
        combo_count <= 1;
      end else if (current_state == COMB_GEN && next_state == HULL_GEN) begin
        // Generate next combination
        if (select_count == 3) begin
          if (combo[2] < num_posts-1) combo[2] <= combo[2] + 1;
          else if (combo[1] < num_posts-2) begin
            combo[1] <= combo[1] + 1;
            combo[2] <= combo[1] + 2;
          end else if (combo[0] < num_posts-3) begin
            combo[0] <= combo[0] + 1;
            combo[1] <= combo[0] + 1;
            combo[2] <= combo[0] + 2;
          end else begin
            combo_valid <= 0;
            combo_complete <= (combo_count == m_choose_k);
          end
        end else begin // K=4
          if (combo[3] < num_posts-1) combo[3] <= combo[3] + 1;
          else if (combo[2] < num_posts-2) begin
            combo[2] <= combo[2] + 1;
            combo[3] <= combo[2] + 2;
          end else if (combo[1] < num_posts-3) begin
            combo[1] <= combo[1] + 1;
            combo[2] <= combo[1] + 2;
            combo[3] <= combo[1] + 3;
          end else if (combo[0] < num_posts-4) begin
            combo[0] <= combo[0] + 1;
            combo[1] <= combo[0] + 1;
            combo[2] <= combo[0] + 2;
            combo[3] <= combo[0] + 3;
          end else begin
            combo_valid <= 0;
            combo_complete <= (combo_count == m_choose_k);
          end
        end
        combo_count <= combo_count + 1;
        last_combo <= (combo_count == m_choose_k-1);
      end
    end
  end

  // Hull point selection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hull_size <= 0;
      hull_complete <= 0;
      for (int i=0; i<4; i++) hull_x[i] <= 0;
      for (int i=0; i<4; i++) hull_y[i] <= 0;
    end else begin
      hull_complete <= 0;
      if (current_state == HULL_GEN) begin
        case (select_count)
          3: begin
            hull_x[0] <= post_x[combo[0]];
            hull_y[0] <= post_y[combo[0]];
            hull_x[1] <= post_x[combo[1]];
            hull_y[1] <= post_y[combo[1]];
            hull_x[2] <= post_x[combo[2]];
            hull_y[2] <= post_y[combo[2]];
            hull_size <= 3;
            hull_complete <= 1;
          end
          default: begin
            // Basic hull formation (handling just K=4 case)
            hull_x[0] <= post_x[combo[0]];
            hull_y[0] <= post_y[combo[0]];
            hull_x[1] <= post_x[combo[1]];
            hull_y[1] <= post_y[combo[1]];
            hull_x[2] <= post_x[combo[2]];
            hull_y[2] <= post_y[combo[2]];
            hull_x[3] <= post_x[combo[3]];
            hull_y[3] <= post_y[combo[3]];
            hull_size <= 4;
            hull_complete <= 1;
          end
        endcase
      end
    end
  end

  // Point-in-polygon checking
  reg [3:0] edge;
  reg crossings;
  reg [15:0] x1, y1, x2, y2;
  reg [15:0] point_x, point_y;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      onion_idx <= 0;
      protected_count <= 0;
      count_complete <= 0;
      edge <= 0;
      crossings <= 0;
    end else if (current_state == POINT_CHECK) begin
      if (onion_idx < num_onions) begin
        // Ray casting implementation
        point_x = onion_x[onion_idx];
        point_y = onion_y[onion_idx];
        crossings = 0;
        for (edge = 0; edge < hull_size; edge = edge + 1) begin
          x1 = hull_x[edge];
          y1 = hull_y[edge];
          x2 = hull_x[(edge+1)%hull_size];
          y2 = hull_y[(edge+1)%hull_size];
          if ((y1 > point_y) != (y2 > point_y)) begin
            if (point_x < ((x2-x1)*(point_y-y1)/(y2-y1) + x1)) begin
              crossings = crossings + 1;
            end
          end
        end
        if (crossings[0]) protected_count <= protected_count + 1;
        onion_idx <= onion_idx + 1;
      end else begin
        // Finished checking all onions
        count_complete <= 1;
        onion_idx <= 0;
      end
    end else if (current_state == UPDATE_MAX) begin
      if (protected_count > current_max) current_max <= protected_count;
      protected_count <= 0;
      count_complete <= 0;
    end else if (current_state == IDLE) begin
      protected_count <= 0;
    end
  end

  // Max update and output
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_max <= 0;
      done <= 0;
    end else if (current_state == UPDATE_MAX) begin
      if (combo_complete) begin
        max_protected <= current_max;
        done <= 1;
      end
    end else if (current_state == DONE) begin
      done <= 1;
    end else if (current_state == IDLE) begin
      done <= 0;
      current_max <= 0;
    end
  end

endmodule