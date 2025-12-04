module race_checker(
  input clk,
  input rst_n,
  input start,
  input [15:0] L,
  input [15:0] dist_matrix [0:3][0:3],
  output reg result,
  output reg done
);

  typedef enum logic [3:0] {
    IDLE          = 4'b0000,
    CALC_PERM_1   = 4'b0001,
    CALC_PERM_2   = 4'b0010,
    CALC_PERM_3   = 4'b0011,
    CALC_PERM_4   = 4'b0100,
    CALC_PERM_5   = 4'b0101,
    CALC_PERM_6   = 4'b0110,
    CHECK_DONE    = 4'b0111
  } state_t;

  state_t state, next_state;

  logic [15:0] sum;

  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_PERM_1;
        else       next_state = IDLE;
      end
      CALC_PERM_1: next_state = CALC_PERM_2;
      CALC_PERM_2: next_state = CALC_PERM_3;
      CALC_PERM_3: next_state = CALC_PERM_4;
      CALC_PERM_4: next_state = CALC_PERM_5;
      CALC_PERM_5: next_state = CALC_PERM_6;
      CALC_PERM_6: next_state = CHECK_DONE;
      CHECK_DONE: next_state = CHECK_DONE;
      default: next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      done    <= 1'b0;
      result  <= 1'b0;
    end else begin
      state <= next_state;

      if (state == IDLE) begin
        done   <= 1'b0;
        result <= 1'b0;
      end else if (state == CALC_PERM_1) begin
        sum    <= dist_matrix[0][1] + dist_matrix[1][2] + dist_matrix[2][3] + dist_matrix[3][0];
        result <= (dist_matrix[0][1] + dist_matrix[1][2] + dist_matrix[2][3] + dist_matrix[3][0] == L);
      end else if (state == CALC_PERM_2) begin
        sum    <= dist_matrix[0][1] + dist_matrix[1][3] + dist_matrix[3][2] + dist_matrix[2][0];
        result <= (dist_matrix[0][1] + dist_matrix[1][3] + dist_matrix[3][2] + dist_matrix[2][0] == L);
      end else if (state == CALC_PERM_3) begin
        sum    <= dist_matrix[0][2] + dist_matrix[2][1] + dist_matrix[1][3] + dist_matrix[3][0];
        result <= (dist_matrix[0][2] + dist_matrix[2][1] + dist_matrix[1][3] + dist_matrix[3][0] == L);
      end else if (state == CALC_PERM_4) begin
        sum    <= dist_matrix[0][2] + dist_matrix[2][3] + dist_matrix[3][1] + dist_matrix[1][0];
        result <= (dist_matrix[0][2] + dist_matrix[2][3] + dist_matrix[3][1] + dist_matrix[1][0] == L);
      end else if (state == CALC_PERM_5) begin
        sum    <= dist_matrix[0][3] + dist_matrix[3][1] + dist_matrix[1][2] + dist_matrix[2][0];
        result <= (dist_matrix[0][3] + dist_matrix[3][1] + dist_matrix[1][2] + dist_matrix[2][0] == L);
      end else if (state == CALC_PERM_6) begin
        sum    <= dist_matrix[0][3] + dist_matrix[3][2] + dist_matrix[2][1] + dist_matrix[1][0];
        result <= (dist_matrix[0][3] + dist_matrix[3][2] + dist_matrix[2][1] + dist_matrix[1][0] == L);
      end else if (state == CHECK_DONE) begin
        done   <= 1'b1;
      end
    end
  end
endmodule