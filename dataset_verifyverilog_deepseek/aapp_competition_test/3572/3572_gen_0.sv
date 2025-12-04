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
  IDLE         = 4'd0,
  CALC_PERM_1  = 4'd1,
  CALC_PERM_2  = 4'd2,
  CALC_PERM_3  = 4'd3,
  CALC_PERM_4  = 4'd4,
  CALC_PERM_5  = 4'd5,
  CALC_PERM_6  = 4'd6,
  CHECK_DONE   = 4'd7
} state_t;

reg [3:0] current_state, next_state;
reg found;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    found <= 1'b0;
    done <= 1'b0;
    result <= 1'b0;
  end else begin
    current_state <= next_state;
    
    case (current_state)
      IDLE: begin
        done <= 1'b0;
        result <= 1'b0;
        if (start) found <= 1'b0;
      end
      
      CALC_PERM_1: begin
        if ((dist_matrix[0][1] + dist_matrix[1][2] + dist_matrix[2][3] + dist_matrix[3][0]) == L)
          found <= 1'b1;
      end
      
      CALC_PERM_2: begin
        if ((dist_matrix[0][1] + dist_matrix[1][3] + dist_matrix[3][2] + dist_matrix[2][0]) == L)
          found <= 1'b1;
      end
      
      CALC_PERM_3: begin
        if ((dist_matrix[0][2] + dist_matrix[2][1] + dist_matrix[1][3] + dist_matrix[3][0]) == L)
          found <= 1'b1;
      end
      
      CALC_PERM_4: begin
        if ((dist_matrix[0][2] + dist_matrix[2][3] + dist_matrix[3][1] + dist_matrix[1][0]) == L)
          found <= 1'b1;
      end
      
      CALC_PERM_5: begin
        if ((dist_matrix[0][3] + dist_matrix[3][1] + dist_matrix[1][2] + dist_matrix[2][0]) == L)
          found <= 1'b1;
      end
      
      CALC_PERM_6: begin
        if ((dist_matrix[0][3] + dist_matrix[3][2] + dist_matrix[2][1] + dist_matrix[1][0]) == L)
          found <= 1'b1;
      end
      
      CHECK_DONE: begin
        done <= 1'b1;
        result <= found;
      end
    endcase
  end
end

always_comb begin
  next_state = current_state;
  
  case (current_state)
    IDLE:        if (start & !done) next_state = CALC_PERM_1;
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