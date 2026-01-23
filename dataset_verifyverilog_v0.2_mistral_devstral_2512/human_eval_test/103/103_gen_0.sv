module rounded_avg (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] m,
  output reg [7:0] result,
  output reg error,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_RANGE,
    CALC_SUM,
    CALC_COUNT,
    DIVIDE,
    ROUND,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [8:0] sum; // 9-bit to prevent overflow
  reg [7:0] count;
  reg [7:0] average;
  reg [7:0] remainder;
  reg [7:0] round_threshold;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 8'b0;
      error <= 1'b0;
      done <= 1'b0;
      sum <= 9'b0;
      count <= 8'b0;
      average <= 8'b0;
      remainder <= 8'b0;
      round_threshold <= 8'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_RANGE;
          error = 1'b0;
          done = 1'b0;
        end
      end
      CHECK_RANGE: begin
        if (n > m) begin
          next_state = DONE;
          error = 1'b1;
        end else begin
          next_state = CALC_SUM;
        end
      end
      CALC_SUM: next_state = CALC_COUNT;
      CALC_COUNT: next_state = DIVIDE;
      DIVIDE: next_state = ROUND;
      ROUND: next_state = DONE;
      DONE: begin
        next_state = IDLE;
        done = 1'b1;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum <= 9'b0;
      count <= 8'b0;
      average <= 8'b0;
      remainder <= 8'b0;
      round_threshold <= 8'b0;
    end else begin
      case (current_state)
        CALC_SUM: sum <= n + m;
        CALC_COUNT: count <= m - n + 1;
        DIVIDE: begin
          average <= sum / count;
          remainder <= sum % count;
        end
        ROUND: begin
          round_threshold <= (count + 1) / 2;
          if (remainder >= round_threshold) begin
            average <= average + 1;
          end
          result <= average;
        end
        DONE: begin
          if (error) begin
            result <= 8'b0;
          end
        end
      endcase
    end
  end

endmodule