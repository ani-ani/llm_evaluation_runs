module fence_cuts (
  input clk,
  input rst_n,
  input start,
  input [7:0] k,
  input [7:0] n,
  input [7:0] p0,
  input [7:0] p1,
  input [7:0] p2,
  input [7:0] p3,
  output reg [7:0] min_cuts,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SEARCH,
    CALC,
    UPDATE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0] low, high, mid;
  reg [7:0] best_L;
  reg [7:0] total_posts;
  reg [7:0] current_cuts;
  reg [7:0] max_pole;
  reg [7:0] poles [0:3];
  reg [7:0] i;
  reg [7:0] temp_posts;
  reg [7:0] temp_cuts;

  // Assign poles array
  always @* begin
    poles[0] = p0;
    poles[1] = p1;
    poles[2] = p2;
    poles[3] = p3;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_cuts <= 0;
      low <= 0;
      high <= 0;
      mid <= 0;
      best_L <= 0;
      total_posts <= 0;
      current_cuts <= 0;
      max_pole <= 0;
      i <= 0;
      temp_posts <= 0;
      temp_cuts <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = SEARCH;
          // Initialize max_pole
          max_pole = poles[0];
          for (int j = 1; j < 4; j++) begin
            if (poles[j] > max_pole) max_pole = poles[j];
          end
          low = 1;
          high = max_pole;
          best_L = 0;
          done = 0;
        end
      end
      SEARCH: begin
        if (low <= high) begin
          mid = (low + high) / 2;
          next_state = CALC;
        end else begin
          next_state = DONE;
        end
      end
      CALC: begin
        temp_posts = 0;
        temp_cuts = 0;
        for (int j = 0; j < 4; j++) begin
          if (poles[j] >= mid) begin
            temp_posts = temp_posts + (poles[j] / mid);
            if (poles[j] % mid == 0) begin
              if ((poles[j] / mid) > 0) temp_cuts = temp_cuts + ((poles[j] / mid) - 1);
            end else begin
              temp_cuts = temp_cuts + (poles[j] / mid);
            end
          end
        end
        next_state = UPDATE;
      end
      UPDATE: begin
        if (temp_posts >= n) begin
          best_L = mid;
          low = mid + 1;
        end else begin
          high = mid - 1;
        end
        next_state = SEARCH;
      end
      DONE: begin
        // Compute final cuts for best_L
        current_cuts = 0;
        for (int j = 0; j < 4; j++) begin
          if (poles[j] >= best_L) begin
            if (poles[j] % best_L == 0) begin
              if ((poles[j] / best_L) > 0) current_cuts = current_cuts + ((poles[j] / best_L) - 1);
            end else begin
              current_cuts = current_cuts + (poles[j] / best_L);
            end
          end
        end
        min_cuts = current_cuts;
        done = 1;
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule