module stove_cooking (
  input clk,
  input rst_n,
  input start,
  input [63:0] k_in,
  input [63:0] d_in,
  input [63:0] t_in,
  output reg [63:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    SETUP_ITER,
    CHECK_Cooking,
    UPDATE_Bounds,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Binary search variables
  reg [63:0] low;
  reg [63:0] high;
  reg [63:0] mid;
  reg [5:0] iter_count;

  // Intermediate calculation variables
  reg [63:0] cycle_len;
  reg [63:0] on_time;
  reg [63:0] off_time;
  reg [63:0] heat_per_cycle;
  reg [63:0] full_cycles;
  reg [63:0] remaining_time;
  reg [63:0] remaining_heat;
  reg [63:0] total_cooking;
  reg [63:0] cooking_done;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      result <= 0;
      iter_count <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = SETUP_ITER;
      end
      SETUP_ITER: begin
        next_state = CHECK_Cooking;
      end
      CHECK_Cooking: begin
        next_state = UPDATE_Bounds;
      end
      UPDATE_Bounds: begin
        if (iter_count == 63) next_state = DONE;
        else next_state = SETUP_ITER;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      low <= 0;
      high <= 0;
      mid <= 0;
      iter_count <= 0;
      cycle_len <= 0;
      on_time <= 0;
      off_time <= 0;
      heat_per_cycle <= 0;
      full_cycles <= 0;
      remaining_time <= 0;
      remaining_heat <= 0;
      total_cooking <= 0;
      cooking_done <= 0;
    end else begin
      case (current_state)
        SETUP_ITER: begin
          if (iter_count == 0) begin
            low <= 0;
            high <= 2 * t_in;
          end
          mid <= (low + high) / 2;
        end
        CHECK_Cooking: begin
          // Calculate cycle_len = ceil(k_in / d_in) * d_in
          cycle_len <= (k_in + d_in - 1) / d_in * d_in;
          on_time <= k_in;
          off_time <= cycle_len - k_in;
          heat_per_cycle <= (on_time * 2) + off_time;
          full_cycles <= mid / cycle_len;
          remaining_time <= mid % cycle_len;
          if (remaining_time < on_time)
            remaining_heat <= remaining_time * 2;
          else
            remaining_heat <= (on_time * 2) + (remaining_time - on_time);
          total_cooking <= (full_cycles * heat_per_cycle) + remaining_heat;
          cooking_done <= (total_cooking >= 2 * t_in);
        end
        UPDATE_Bounds: begin
          if (cooking_done) begin
            high <= mid;
          end else begin
            low <= mid + 1;
          end
          iter_count <= iter_count + 1;
        end
        DONE: begin
          result <= mid;
          done <= 1;
        end
        default: ;
      endcase
    end
  end

endmodule