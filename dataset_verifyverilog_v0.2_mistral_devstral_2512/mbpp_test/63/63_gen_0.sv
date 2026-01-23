module max_difference (
  input clk,
  input rst_n,
  input start,
  input [4:0] num_pairs,
  input [7:0] pairs [0:7],
  output reg [7:0] max_diff,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_PAIR,
    COMPUTE_DIFF,
    UPDATE_MAX,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] a_reg, b_reg;
  reg [7:0] current_diff;
  reg [2:0] pair_counter;
  reg [7:0] max_diff_reg;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_diff_reg <= 8'b0;
      done <= 1'b0;
      pair_counter <= 3'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = READ_PAIR;
      end
      READ_PAIR: begin
        next_state = COMPUTE_DIFF;
      end
      COMPUTE_DIFF: begin
        next_state = UPDATE_MAX;
      end
      UPDATE_MAX: begin
        if (pair_counter == num_pairs - 1) begin
          next_state = DONE;
        end else begin
          next_state = READ_PAIR;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_reg <= 8'b0;
      b_reg <= 8'b0;
      current_diff <= 8'b0;
      max_diff_reg <= 8'b0;
      pair_counter <= 3'b0;
    end else begin
      case (current_state)
        READ_PAIR: begin
          a_reg <= pairs[pair_counter * 2];
          b_reg <= pairs[pair_counter * 2 + 1];
        end
        COMPUTE_DIFF: begin
          // Compute absolute difference using two's complement
          if (b_reg >= a_reg) begin
            current_diff <= b_reg - a_reg;
          end else begin
            current_diff <= a_reg - b_reg;
          end
        end
        UPDATE_MAX: begin
          if (current_diff > max_diff_reg) begin
            max_diff_reg <= current_diff;
          end
          pair_counter <= pair_counter + 1;
        end
        DONE: begin
          done <= 1'b1;
        end
        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

  // Output assignment
  assign max_diff = max_diff_reg;

endmodule