module even_odd_counter (
  input clk,
  input rst_n,
  input start,
  input signed [15:0] num,
  output reg [3:0] even_count,
  output reg [3:0] odd_count,
  output reg done
);
  
  typedef enum logic [1:0] {IDLE, PROCESSING, DONE_ST} state_t;
  state_t curr_state, next_state;
  
  logic [15:0] abs_num, next_abs_num;
  logic [2:0] dig_cnt, next_dig_cnt;
  logic [3:0] even_next, odd_next;
  logic done_next;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      curr_state <= IDLE;
      abs_num <= 16'b0;
      dig_cnt <= 3'b0;
      even_count <= 4'b0;
      odd_count <= 4'b0;
      done <= 1'b0;
    end else begin
      curr_state <= next_state;
      abs_num <= next_abs_num;
      dig_cnt <= next_dig_cnt;
      even_count <= even_next;
      odd_count <= odd_next;
      done <= done_next;
    end
  end
  
  always_comb begin
    next_state = curr_state;
    next_abs_num = abs_num;
    next_dig_cnt = dig_cnt;
    even_next = even_count;
    odd_next = odd_count;
    done_next = 1'b0;
    
    case (curr_state)
      IDLE: begin
        if (start) begin
          next_abs_num = (num < 0) ? -num : num;
          next_dig_cnt = 0;
          even_next = 0;
          odd_next = 0;
          next_state = PROCESSING;
        end
      end
      
      PROCESSING: begin
        logic [3:0] digit = abs_num % 10;
        
        if (digit[0] == 0) even_next = even_count + 1;
        else odd_next = odd_count + 1;
        
        next_abs_num = abs_num / 10;
        next_dig_cnt = dig_cnt + 1;
        
        if (dig_cnt == 4 || next_abs_num == 0) next_state = DONE_ST;
        else next_state = PROCESSING;
      end
      
      DONE_ST: begin
        done_next = 1'b1;
        next_state = IDLE;
      end
      
      default: next_state = IDLE;
    endcase
  end
  
endmodule