module digit_sum (
  input clk,
  input rst_n,
  input start,
  input [7:0] numbers [7:0],
  output reg [6:0] total_sum,
  output reg done
);
  
  typedef enum {
    IDLE,
    PROCESSING,
    DONE_ST
  } state_t;
  
  state_t state;
  reg [2:0] current_num_idx;
  reg [1:0] cycle_counter;
  reg [7:0] current_val;
  reg [6:0] temp_digit_sum;
  
  wire [7:0] abs_num = numbers[current_num_idx][7] ? -numbers[current_num_idx] : numbers[current_num_idx];
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      total_sum <= '0;
      done <= '0;
      current_num_idx <= '0;
      cycle_counter <= '0;
      current_val <= '0;
      temp_digit_sum <= '0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= '0;
          if (start) begin
            state <= PROCESSING;
            total_sum <= '0;
            current_num_idx <= '0;
            cycle_counter <= '0;
            current_val <= abs_num;
            temp_digit_sum <= abs_num % 10;
          end
        end
        
        PROCESSING: begin
          case (cycle_counter)
            2'd0: begin
              current_val <= current_val / 10;
              temp_digit_sum <= temp_digit_sum + (current_val % 10);
              cycle_counter <= 2'd1;
            end
            2'd1: begin
              current_val <= current_val / 10;
              temp_digit_sum <= temp_digit_sum + (current_val % 10);
              cycle_counter <= 2'd2;
            end
            2'd2: begin
              temp_digit_sum <= temp_digit_sum + (current_val % 10);
              cycle_counter <= 2'd3;
            end
            2'd3: begin
              total_sum <= total_sum + temp_digit_sum;
              if (current_num_idx == 3'd7) begin
                state <= DONE_ST;
              end
              else begin
                current_num_idx <= current_num_idx + 1;
                cycle_counter <= 2'd0;
                current_val <= abs_num;
                temp_digit_sum <= abs_num % 10;
              end
            end
          endcase
        end
        
        DONE_ST: begin
          done <= 1'b1;
          if (start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end
  
endmodule