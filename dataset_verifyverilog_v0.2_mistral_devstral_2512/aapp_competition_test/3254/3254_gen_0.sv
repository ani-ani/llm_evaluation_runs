module average_solver (
  input clk,
  input rst_n,
  input start,
  input [31:0] target_avg_q16,
  output reg [7:0] count_ones,
  output reg [7:0] count_twos,
  output reg [7:0] count_threes,
  output reg [7:0] count_fours,
  output reg [7:0] count_fives,
  output reg [7:0] total_count,
  output reg done,
  output reg found
);

  // State machine
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    SEARCH,
    DONE
  } state_t;
  state_t state, next_state;

  // Internal registers
  reg [7:0] c1, c2, c3, c4, c5;
  reg [7:0] total;
  reg [31:0] sum;
  reg [31:0] target_times_total;
  reg [31:0] sum_q16;
  reg [31:0] target_q16;
  reg [31:0] diff;
  reg [7:0] found_c1, found_c2, found_c3, found_c4, found_c5;
  reg [7:0] found_total;
  reg found_flag;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      found <= 0;
      count_ones <= 0;
      count_twos <= 0;
      count_threes <= 0;
      count_fours <= 0;
      count_fives <= 0;
      total_count <= 0;
      c1 <= 0;
      c2 <= 0;
      c3 <= 0;
      c4 <= 0;
      c5 <= 0;
      total <= 0;
      sum <= 0;
      target_times_total <= 0;
      sum_q16 <= 0;
      target_q16 <= 0;
      diff <= 0;
      found_c1 <= 0;
      found_c2 <= 0;
      found_c3 <= 0;
      found_c4 <= 0;
      found_c5 <= 0;
      found_total <= 0;
      found_flag <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        next_state = SEARCH;
      end
      SEARCH: begin
        if (found_flag || total == 16) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Search logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      c1 <= 0;
      c2 <= 0;
      c3 <= 0;
      c4 <= 0;
      c5 <= 0;
      total <= 0;
      sum <= 0;
      target_times_total <= 0;
      sum_q16 <= 0;
      target_q16 <= 0;
      diff <= 0;
    end else begin
      case (state)
        INIT: begin
          c1 <= 0;
          c2 <= 0;
          c3 <= 0;
          c4 <= 0;
          c5 <= 0;
          total <= 1;
          sum <= 0;
          target_times_total <= target_avg_q16 * total;
          sum_q16 <= 0;
          target_q16 <= target_times_total;
          diff <= 0;
        end
        SEARCH: begin
          // Calculate sum
          sum <= c1 * 1 + c2 * 2 + c3 * 3 + c4 * 4 + c5 * 5;
          sum_q16 <= sum << 16;
          target_q16 <= target_times_total;
          diff <= sum_q16 - target_q16;

          // Check if solution found
          if (diff == 0 && !found_flag) begin
            found_c1 <= c1;
            found_c2 <= c2;
            found_c3 <= c3;
            found_c4 <= c4;
            found_c5 <= c5;
            found_total <= total;
            found_flag <= 1;
          end

          // Generate next combination
          if (c5 < total) begin
            c5 <= c5 + 1;
          end else if (c4 < total) begin
            c5 <= 0;
            c4 <= c4 + 1;
          end else if (c3 < total) begin
            c5 <= 0;
            c4 <= 0;
            c3 <= c3 + 1;
          end else if (c2 < total) begin
            c5 <= 0;
            c4 <= 0;
            c3 <= 0;
            c2 <= c2 + 1;
          end else if (c1 < total) begin
            c5 <= 0;
            c4 <= 0;
            c3 <= 0;
            c2 <= 0;
            c1 <= c1 + 1;
          end else begin
            // Move to next total
            c1 <= 0;
            c2 <= 0;
            c3 <= 0;
            c4 <= 0;
            c5 <= 0;
            total <= total + 1;
            target_times_total <= target_avg_q16 * total;
          end
        end
        DONE: begin
          done <= 1;
          found <= found_flag;
          count_ones <= found_c1;
          count_twos <= found_c2;
          count_threes <= found_c3;
          count_fours <= found_c4;
          count_fives <= found_c5;
          total_count <= found_total;
        end
        default: begin
          c1 <= 0;
          c2 <= 0;
          c3 <= 0;
          c4 <= 0;
          c5 <= 0;
          total <= 0;
          sum <= 0;
          target_times_total <= 0;
          sum_q16 <= 0;
          target_q16 <= 0;
          diff <= 0;
        end
      endcase
    end
  end

endmodule