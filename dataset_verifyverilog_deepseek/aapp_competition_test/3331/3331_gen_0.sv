module horse_chase(
  input clk,
  input rst_n,
  input start,
  input [3:0] L,
  input [3:0] A,
  input [3:0] B,
  input [3:0] P,
  output reg [4:0] time_out,
  output reg done
);
  typedef enum logic [1:0] { IDLE, INIT, PROCESS, CAPTURED } state_t;
  state_t state, next_state;
  reg [3:0] A_curr, B_curr, P_curr;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      A_curr <= 4'b0;
      B_curr <= 4'b0;
      P_curr <= 4'b0;
      time_out <= 5'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      case (next_state)
        INIT: begin
          A_curr <= A;
          B_curr <= B;
          P_curr <= P;
          time_out <= 5'b0;
          done <= 1'b0;
        end
        PROCESS: begin
          A_curr <= A_next;
          B_curr <= B_next;
          P_curr <= P_next;
          time_out <= time_out_next;
          done <= done_next;
        end
        CAPTURED: begin
          done <= 1'b1;
          time_out <= time_out_next;
        end
        default: begin
          done <= done_next;
          time_out <= time_out_next;
        end
      endcase
    end
  end
  
  reg [3:0] A_next, B_next, P_next;
  reg [4:0] time_out_next;
  reg done_next;
  reg [3:0] move_step;
  
  always_comb begin
    next_state = state;
    A_next = A_curr;
    B_next = B_curr;
    P_next = P_curr;
    time_out_next = time_out;
    done_next = done;
    move_step = 2;
    
    unique case (state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
          done_next = 1'b0;
          time_out_next = 5'b0;
        end
      end
      
      INIT: begin
        next_state = PROCESS;
      end
      
      PROCESS: begin
        // Cow A movement
        if ((A_curr < P_curr) && ((P_curr - A_curr) > 1)) A_next = A_curr + 1;
        else if ((A_curr > P_curr) && ((A_curr - P_curr) > 1)) A_next = A_curr - 1;
        
        // Cow B movement
        if ((B_curr < P_curr) && ((P_curr - B_curr) > 1)) B_next = B_curr + 1;
        else if ((B_curr > P_curr) && ((B_curr - P_curr) > 1)) B_next = B_curr - 1;
        
        // Horse move step
        if ((A_next == P_curr) || (B_next == P_curr)) move_step = 1;
        
        // Calculate horse moves with boundary checks
        logic [3:0] left_pos = (P_curr >= move_step) ? (P_curr - move_step) : 4'b0;
        left_pos = (left_pos > L) ? L : left_pos;
        logic [3:0] right_pos = (P_curr + move_step > L) ? L : (P_curr + move_step);
        
        // Distance calculations
        logic [3:0] distA_left = (left_pos >= A_next) ? (left_pos - A_next) : (A_next - left_pos);
        logic [3:0] distB_left = (left_pos >= B_next) ? (left_pos - B_next) : (B_next - left_pos);
        logic [3:0] min_left = (distA_left < distB_left) ? distA_left : distB_left;
        
        logic [3:0] distA_right = (right_pos >= A_next) ? (right_pos - A_next) : (A_next - right_pos);
        logic [3:0] distB_right = (right_pos >= B_next) ? (right_pos - B_next) : (B_next - right_pos);
        logic [3:0] min_right = (distA_right < distB_right) ? distA_right : distB_right;
        
        // Direction selection
        if (min_left >= min_right) P_next = left_pos;
        else P_next = right_pos;
        
        // Capture check
        if ((P_next == A_next) || (P_next == B_next)) begin
          next_state = CAPTURED;
          time_out_next = time_out;
          done_next = 1'b1;
        end else begin
          time_out_next = time_out + 1;
          done_next = 1'b0;
          if (time_out == 5'b11111) next_state = CAPTURED;
          else next_state = PROCESS;
        end
      end
      
      CAPTURED: begin
        done_next = 1'b1;
        next_state = CAPTURED;
      end
      
      default: next_state = IDLE;
    endcase
  end
endmodule