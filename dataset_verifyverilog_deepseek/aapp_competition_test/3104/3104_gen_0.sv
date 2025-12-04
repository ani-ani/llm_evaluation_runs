module min_plus_adder(
  input clk,
  input rst_n,
  input start,
  input [3:0] digit_count,
  input [7:0][3:0] digits,
  input [15:0] target_sum,
  output reg [6:0] plus_positions,
  output reg [3:0] plus_count,
  output reg [15:0] computed_sum,
  output reg done
);

  typedef enum logic [2:0] {IDLE, INIT, EVAL, INCR, FOUND} state_t;
  state_t current_state, next_state;

  reg [2:0] current_k;
  reg [6:0] mask_counter;
  reg found_flag;
  reg [6:0] sol_mask;
  reg [3:0] sol_plus_count;
  reg [15:0] sol_sum;

  wire [6:0] effective_mask = mask_counter & ((1 << (digit_count-1)) - 1);
  wire [3:0] popcount = effective_mask[0] + effective_mask[1] + effective_mask[2]
                      + effective_mask[3] + effective_mask[4] + effective_mask[5]
                      + effective_mask[6];

  reg [15:0] calc_sum;
  always_comb begin
    integer i;
    reg [15:0] current_num;
    calc_sum = 0;
    current_num = 0;
    for(i=0; i<8; i=i+1) begin
      if(i < digit_count) begin
        current_num = current_num * 10 + digits[i];
        if((i < (digit_count - 1)) && effective_mask[i]) begin
          calc_sum = calc_sum + current_num;
          current_num = 0;
        end
      end
    end
    calc_sum = calc_sum + current_num;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      current_state <= IDLE;
      plus_positions <= 0;
      plus_count <= 0;
      computed_sum <= 0;
      done <= 0;
      found_flag <= 0;
      current_k <= 0;
      mask_counter <= 0;
    end else begin
      current_state <= next_state;

      case(current_state)
        IDLE: begin
          done <= 0;
          if(start) begin
            next_state = INIT;
          end
        end
        INIT: begin
          current_k <= 0;
          mask_counter <= 0;
          found_flag <= 0;
          sol_mask <= 0;
          sol_plus_count <= 0;
          sol_sum <= 0;
          next_state = EVAL;
        end
        EVAL: begin
          if(popcount == current_k) begin
            if(calc_sum == target_sum) begin
              found_flag <= 1;
              sol_mask <= effective_mask;
              sol_plus_count <= popcount;
              sol_sum <= calc_sum;
              next_state = FOUND;
            end else begin
              next_state = INCR;
            end
          end else begin
            next_state = INCR;
          end
        end
        INCR: begin
          if(mask_counter == 7'd127) begin
            mask_counter <= 0;
            if(current_k == (digit_count - 1)) begin
              next_state = FOUND;
            end else begin
              current_k <= current_k + 1;
              next_state = EVAL;
            end
          end else begin
            mask_counter <= mask_counter + 1;
            next_state = EVAL;
          end
        end
        FOUND: begin
          done <= 1;
          if(found_flag) begin
            plus_positions <= sol_mask;
            plus_count <= sol_plus_count;
            computed_sum <= sol_sum;
          end
          if(start) next_state = INIT;
          else next_state = FOUND;
        end
        default: next_state = IDLE;
      endcase
    end
  end

endmodule