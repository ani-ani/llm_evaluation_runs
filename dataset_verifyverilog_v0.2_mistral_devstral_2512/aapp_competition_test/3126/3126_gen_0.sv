module frog_dance (
  input clk,
  input rst_n,
  input start,
  input [5:0] frog_positions [49:0],
  input [5:0] num_frogs,
  input [5:0] target_pos,
  output reg [15:0] total_jumps,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PROCESS_FROGS,
    CALCULATE_DISTANCE,
    FIND_MIN_JUMPS,
    UPDATE_SUM,
    DONE
  } state_t;

  state_t state;
  reg [5:0] current_frog;
  reg [5:0] distance;
  reg [5:0] k;
  reg [5:0] sum_k;
  reg [15:0] sum_accum;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_frog <= 0;
      distance <= 0;
      k <= 0;
      sum_k <= 0;
      sum_accum <= 0;
      total_jumps <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESS_FROGS;
            current_frog <= 0;
            sum_accum <= 0;
            done <= 0;
          end
        end
        PROCESS_FROGS: begin
          if (current_frog < num_frogs) begin
            state <= CALCULATE_DISTANCE;
          end else begin
            state <= DONE;
          end
        end
        CALCULATE_DISTANCE: begin
          state <= FIND_MIN_JUMPS;
          k <= 1;
          sum_k <= 1;
        end
        FIND_MIN_JUMPS: begin
          if (sum_k >= distance && (sum_k - distance) % 2 == 0) begin
            state <= UPDATE_SUM;
          end else if (k < 64) begin
            k <= k + 1;
            sum_k <= sum_k + k;
          end else begin
            state <= UPDATE_SUM;
          end
        end
        UPDATE_SUM: begin
          sum_accum <= sum_accum + k;
          current_frog <= current_frog + 1;
          state <= PROCESS_FROGS;
        end
        DONE: begin
          total_jumps <= sum_accum;
          done <= 1;
          if (!start) begin
            state <= IDLE;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

  // Distance calculation
  always @(posedge clk) begin
    if (state == CALCULATE_DISTANCE) begin
      distance <= (frog_positions[current_frog] > target_pos) ?
                  (frog_positions[current_frog] - target_pos) :
                  (target_pos - frog_positions[current_frog]);
    end
  end

endmodule