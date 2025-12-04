module sum_even_factors (
  input clk,
  input rst_n,
  input start,
  input [15:0] n_in,
  output reg [31:0] sum,
  output reg done
);

typedef enum {
  IDLE,
  INIT,
  CHECK_DIVISOR,
  CALC_EXP,
  UPDATE,
  FINAL_MULT,
  DONE_ST
} state_t;

state_t current_state, next_state;
reg [15:0] divisor, divisor_next;
reg [15:0] n, n_next;
reg [31:0] sum_reg, sum_next;
reg [4:0] exp_cnt, exp_next;
wire [15:0] sqrt_n;

// SQRT Approximation via LZC
integer lzc;
always_comb begin
  lzc = 16;
  for (integer i=15; i>=0; i--) begin
    if (n[i]) begin lzc = 15-i; break; end
  end
  sqrt_n = (lzc < 16) ? (1 << (((15-lzc)+1)>>>1)) : 16'd0;
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    sum_reg <= 0;
    done <= 0;
    divisor <= 0;
    exp_cnt <= 0;
    n <= 0;
  end else begin
    current_state <= next_state;
    sum_reg <= sum_next;
    done <= (next_state == DONE_ST) || (next_state == FINAL_MULT && n_next < 2);
    divisor <= divisor_next;
    exp_cnt <= exp_next;
    n <= n_next;
  end
end

always_comb begin
  next_state = current_state;
  sum_next = sum_reg;
  divisor_next = divisor;
  exp_next = exp_cnt;
  n_next = n;
  
  case (current_state)
    IDLE: begin
      if (start) begin
        next_state = INIT;
        n_next = n_in;
      end
    end
    
    INIT: begin
      if (n_in[0]) begin
        sum_next = 0;
        next_state = DONE_ST;
      end else begin
        sum_next = 32'd1;
        divisor_next = 16'd2;
        exp_next = 0;
        next_state = CHECK_DIVISOR;
      end
    end
    
    CHECK_DIVISOR: begin
      if (divisor > sqrt_n) begin
        if (n >= 2) next_state = FINAL_MULT;
        else next_state = DONE_ST;
      end else if (n % divisor == 0) begin
        exp_next = 0;
        next_state = CALC_EXP;
      end else begin
        divisor_next = divisor + 1;
      end
    end
    
    CALC_EXP: begin
      if (n % divisor == 0) begin
        exp_next = exp_cnt + 1;
        n_next = n / divisor;
      end else begin
        next_state = UPDATE;
      end
    end
    
    UPDATE: begin
      automatic logic [31:0] current_term = 32'd1;
      automatic logic [31:0] pow_val = divisor;
      for (int i=0; i<exp_cnt; i++) begin
        current_term = current_term + pow_val;
        pow_val = pow_val * divisor;
      end
      sum_next = sum_reg * current_term;
      divisor_next = divisor + 1;
      next_state = CHECK_DIVISOR;
    end
    
    FINAL_MULT: begin
      if (n >= 2) sum_next = sum_reg * (n + 1);
      next_state = DONE_ST;
    end
    
    DONE_ST: begin
      if (start) next_state = INIT;
    end
    
    default: next_state = IDLE;
  endcase
end

assign sum = sum_reg;

endmodule