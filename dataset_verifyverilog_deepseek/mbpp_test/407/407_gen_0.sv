module next_bigger_num(input clk, input rst_n, input start, input [9:0] num, output reg [9:0] next_num, output reg done, output reg no_bigger);
  
  typedef enum logic [2:0] {IDLE=0, FIND_PIVOT=1, FIND_MIN=2, SWAP_SORT=3, VALID=4} state_t;
  
  reg [2:0] state, next_state;
  reg [3:0] h,t,u;
  reg [3:0] n_h,n_t,n_u;
  reg found_pivot, next_found;
  reg [1:0] pivot_pos, next_pivot_pos;
  reg [3:0] pivot_val, next_pivot_val;
  reg [3:0] min_digit, next_min_digit;
  reg [1:0] min_pos, next_min_pos;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      h <= 0; t <= 0; u <= 0;
      found_pivot <= 0;
      pivot_pos <= 0;
      pivot_val <= 0;
      min_digit <= 0;
      min_pos <= 0;
    end else begin
      state <= next_state;
      h <= n_h; t <= n_t; u <= n_u;
      found_pivot <= next_found;
      pivot_pos <= next_pivot_pos;
      pivot_val <= next_pivot_val;
      min_digit <= next_min_digit;
      min_pos <= next_min_pos;
    end
  end
  
  always_comb begin
    next_state = state;
    n_h = h; n_t = t; n_u = u;
    next_found = found_pivot;
    next_pivot_pos = pivot_pos;
    next_pivot_val = pivot_val;
    next_min_digit = min_digit;
    next_min_pos = min_pos;
    done = 0; no_bigger = 0;
    
    case (state)
      IDLE: begin
        if (start) begin
          n_h = num/100;
          n_t = (num%100)/10;
          n_u = num%10;
          next_state = FIND_PIVOT;
        end
      end
      
      FIND_PIVOT: begin
        next_found = 0;
        if (t < u) begin
          next_found = 1;
          next_pivot_pos = 1;
          next_pivot_val = t;
        end else if (h < t) begin
          next_found = 1;
          next_pivot_pos = 0;
          next_pivot_val = h;
        end
        next_state = found_pivot ? FIND_MIN : VALID;
      end
      
      FIND_MIN: begin
        if (pivot_pos == 1) begin
          next_min_digit = u;
          next_min_pos = 2;
        end else begin
          if (u > pivot_val && (t <= u || u < t)) begin
            next_min_digit = (u < t) ? u : (u < pivot_val) ? t : u;
            next_min_pos = (u < t || u <= pivot_val) ? 1 : 2;
          end else begin
            next_min_digit = t;
            next_min_pos = 1;
          end
        end
        next_state = SWAP_SORT;
      end
      
      SWAP_SORT: begin
        if (pivot_pos == 0) begin
          if (min_pos == 1) begin
            n_h = t;
            n_t = h;
            if (n_t > u) begin
              n_t = u;
              n_u = h;
            end
          end else begin
            n_h = u;
            n_u = h;
            if (t > n_u) begin
              n_t = n_u;
              n_u = t;
            end
          end
        end else begin
          n_t = u;
          n_u = t;
        end
        next_state = VALID;
      end
      
      VALID: begin
        done = 1;
        if (~found_pivot) no_bigger = 1;
        else next_num = h*100 + t*10 + u;
        next_state = IDLE;
      end
    endcase
  end
endmodule