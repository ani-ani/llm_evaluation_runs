module multi_int_concat (
  input clk,
  input rst_n,
  input start,
  input [3:0][7:0] nums,
  output reg [31:0] result,
  output reg done
);

typedef enum logic [1:0] { IDLE, PROCESS_NUM, CONVERT_DIGITS, FINISH } state_t;

state_t current_state, next_state;
reg [1:0] index;
reg sign_reg;
reg [31:0] temp_result;
reg [7:0] abs_val;

logic signed [7:0] current_num_signed;

always_comb begin
  current_num_signed = $signed(nums[index]);
  next_state = current_state;
  case (current_state)
    IDLE:    if (start) next_state = PROCESS_NUM;
    PROCESS_NUM:    next_state = CONVERT_DIGITS;
    CONVERT_DIGITS: next_state = (index == 2'd3) ? FINISH : PROCESS_NUM;
    FINISH:   next_state = IDLE;
    default:  next_state = IDLE;
  endcase
end

logic [7:0] digits_val;
logic [3:0] h, t, u;
logic [7:0] remainder;

always_comb begin
  h = 0;
  t = 0;
  u = 0;
  digits_val = 0;
  remainder = 0;
  if (current_state == CONVERT_DIGITS) begin
    h = abs_val / 100;
    remainder = abs_val % 100;
    t = remainder / 10;
    u = remainder % 10;
    digits_val = 100*h + 10*t + u;
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    index <= 2'b0;
    sign_reg <= 1'b0;
    temp_result <= 32'b0;
    result <= 32'b0;
    done <= 1'b0;
    abs_val <= 8'b0;
  end else begin
    current_state <= next_state;
    case (current_state)
      IDLE: begin
        done <= 1'b0;
        if (start) begin
          index <= 2'b0;
          temp_result <= 32'b0;
          sign_reg <= 1'b0;
        end
      end
      
      PROCESS_NUM: begin
        abs_val <= (current_num_signed < 0) ? -current_num_signed : current_num_signed;
        if (index == 0)
          sign_reg <= (current_num_signed < 0) ? 1'b1 : 1'b0;
      end
      
      CONVERT_DIGITS: begin
        if (index == 0)
          temp_result <= digits_val;
        else
          temp_result <= temp_result * 32'd1000 + digits_val;
        index <= index + 1;
      end
      
      FINISH: begin
        result <= sign_reg ? -temp_result : temp_result;
        done <= 1'b1;
      end
    endcase
  end
end

endmodule