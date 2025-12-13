module race_checker(
  input clk,
  input rst_n,
  input start,
  input [15:0] L,
  input [15:0] dist_matrix [0:3][0:3],
  output reg result,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE          = 3'd0,
    CALC_PERM_1   = 3'd1,
    CALC_PERM_2   = 3'd2,
    CALC_PERM_3   = 3'd3,
    CALC_PERM_4   = 3'd4,
    CALC_PERM_5   = 3'd5,
    CALC_PERM_6   = 3'd6,
    CHECK_DONE    = 3'd7
  } state_t;

  state_t state, next_state;

  // Accumulator for path length (up to 4 * 16-bit => 18 bits)
  reg [17:0] sum;

  // Sequential state and outputs update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      result <= 1'b0;
      done   <= 1'b0;
      sum    <= 18'd0;
    end else begin
      state <= next_state;

      case (next_state)
        IDLE: begin
          if (!start) begin
            // Hold result and done until next start or reset
            done <= done;
            result <= result;
          end else begin
            // Start asserted: clear for new computation
            result <= 1'b0;
            done   <= 1'b0;
          end
          sum <= 18'd0;
        end

        CALC_PERM_1: begin
          // Permutation: 0-1-2-3-0
          sum <= dist_matrix[0][1] + dist_matrix[1][2] +
                 dist_matrix[2][3] + dist_matrix[3][0];
          if (sum[15:0] == L)
            result <= 1'b1;
        end

        CALC_PERM_2: begin
          // Permutation: 0-1-3-2-0
          sum <= dist_matrix[0][1] + dist_matrix[1][3] +
                 dist_matrix[3][2] + dist_matrix[2][0];
          if (sum[15:0] == L)
            result <= 1'b1;
        end

        CALC_PERM_3: begin
          // Permutation: 0-2-1-3-0
          sum <= dist_matrix[0][2] + dist_matrix[2][1] +
                 dist_matrix[1][3] + dist_matrix[3][0];
          if (sum[15:0] == L)
            result <= 1'b1;
        end

        CALC_PERM_4: begin
          // Permutation: 0-2-3-1-0
          sum <= dist_matrix[0][2] + dist_matrix[2][3] +
                 dist_matrix[3][1] + dist_matrix[1][0];
          if (sum[15:0] == L)
            result <= 1'b1;
        end

        CALC_PERM_5: begin
          // Permutation: 0-3-1-2-0
          sum <= dist_matrix[0][3] + dist_matrix[3][1] +
                 dist_matrix[1][2] + dist_matrix[2][0];
          if (sum[15:0] == L)
            result <= 1'b1;
        end

        CALC_PERM_6: begin
          // Permutation: 0-3-2-1-0
          sum <= dist_matrix[0][3] + dist_matrix[3][2] +
                 dist_matrix[2][1] + dist_matrix[1][0];
          if (sum[15:0] == L)
            result <= 1'b1;
        end

        CHECK_DONE: begin
          done <= 1'b1;
          sum  <= sum;
          result <= result;
        end

        default: begin
          // Safety default
          state  <= IDLE;
          result <= 1'b0;
          done   <= 1'b0;
          sum    <= 18'd0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALC_PERM_1;
        else
          next_state = IDLE;
      end

      CALC_PERM_1: next_state = CALC_PERM_2;
      CALC_PERM_2: next_state = CALC_PERM_3;
      CALC_PERM_3: next_state = CALC_PERM_4;
      CALC_PERM_4: next_state = CALC_PERM_5;
      CALC_PERM_5: next_state = CALC_PERM_6;
      CALC_PERM_6: next_state = CHECK_DONE;
      CHECK_DONE:  next_state = CHECK_DONE;
      default:     next_state = IDLE;
    endcase
  end

endmodule
