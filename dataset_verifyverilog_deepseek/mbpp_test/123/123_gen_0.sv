module amicable_sum(input clk, input rst_n, input start, input [15:0] limit, output reg [15:0] sum, output reg done);
  parameter IDLE = 4'd0;
  parameter INIT = 4'd1;
  parameter CALC_DIVISORS = 4'd2;
  parameter WAIT_CALC_DONE = 4'd3;
  parameter CHECK_SUM1 = 4'd4;
  parameter INCREMENT_I = 4'd5;
  parameter CHECK_AMICABLE = 4'd6;
  parameter DONE_STATE = 4'd7;
  reg [3:0] state;
  reg [15:0] i;
  reg [15:0] current_num;
  reg [15:0] j;
  reg [15:0] temp_sum;
  reg [15:0] sum1_val;
  reg [15:0] sum2_val;
  reg calculating_sum1;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum <= 0;
      done <= 0;
      i <= 0;
      current_num <= 0;
      j <= 0;
      temp_sum <= 0;
      sum1_val <= 0;
      sum2_val <= 0;
      calculating_sum1 <= 0;
    end
    else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) state <= INIT;
        end
        INIT: begin
          sum <= 0;
          i <= 2;
          current_num <= 2;
          j <= 1;
          temp_sum <= 0;
          calculating_sum1 <= 1;
          state <= CALC_DIVISORS;
        end
        CALC_DIVISORS: begin
          if (j * 2 <= current_num) begin
            if (current_num % j == 0) temp_sum <= temp_sum + j;
            j <= j + 1;
            state <= CALC_DIVISORS;
          end
          else state <= WAIT_CALC_DONE;
        end
        WAIT_CALC_DONE: begin
          if (calculating_sum1) begin
            sum1_val <= temp_sum;
            state <= CHECK_SUM1;
          end
          else begin
            sum2_val <= temp_sum;
            state <= CHECK_AMICABLE;
          end
        end
        CHECK_SUM1: begin
          if (sum1_val > i) begin
            current_num <= sum1_val;
            j <= 1;
            temp_sum <= 0;
            calculating_sum1 <= 0;
            state <= CALC_DIVISORS;
          end
          else state <= INCREMENT_I;
        end
        CHECK_AMICABLE: begin
          if (sum2_val == i && sum1_val <= limit) sum <= sum + i + sum1_val;
          state <= INCREMENT_I;
        end
        INCREMENT_I: begin
          i <= i + 1;
          if (i < limit) begin
            current_num <= i + 1;
            j <= 1;
            temp_sum <= 0;
            calculating_sum1 <= 1;
            state <= CALC_DIVISORS;
          end
          else state <= DONE_STATE;
        end
        DONE_STATE: begin
          done <= 1;
          if (start) state <= INIT;
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule