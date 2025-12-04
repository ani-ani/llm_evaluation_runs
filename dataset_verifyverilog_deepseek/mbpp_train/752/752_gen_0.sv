module jacobsthal_calculator (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [15:0] result,
  output reg done
);
  
  typedef enum logic [1:0] {IDLE, PREP, CALC, FINISH} state_t;
  state_t state, next_state;
  
  reg [3:0] n_reg;
  reg [3:0] cnt;
  reg [15:0] j_prev, j_curr;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'h0;
      done <= 1'b0;
      j_prev <= 16'h0;
      j_curr <= 16'h0;
      cnt <= 4'h0;
      n_reg <= 4'h0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            n_reg <= n;
            next_state <= PREP;
          end
        end
        
        PREP: begin
          done <= 1'b0;
          cnt <= 4'h2;
          j_prev <= 16'h0; // J(0)
          j_curr <= 16'h1; // J(1)
          
          if (n_reg == 0) begin
            result <= 16'h0;
            next_state <= FINISH;
          end else if (n_reg == 1) begin
            result <= 16'h1;
            next_state <= FINISH;
          end else begin
            next_state <= CALC;
          end
        end
        
        CALC: begin
          done <= 1'b0;
          if (cnt <= n_reg) begin
            {j_prev, j_curr} <= {j_curr, j_curr + (j_prev << 1)};
            cnt <= cnt + 1;
          end else begin
            result <= j_curr;
            next_state <= FINISH;
          end
        end
        
        FINISH: begin
          done <= 1'b1;
          next_state <= IDLE;
        end
        
        default: next_state <= IDLE;
      endcase
    end
  end
  
  always_comb begin
    next_state = state;
    case(state)
      IDLE: next_state = start ? PREP : IDLE;
      PREP: begin
        if (n_reg < 2) next_state = FINISH;
        else next_state = CALC;
      end
      CALC: if (cnt > n_reg) next_state = FINISH;
      FINISH: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
endmodule