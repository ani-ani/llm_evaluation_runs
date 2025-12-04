module divisible_checker(input clk, rst_n, start, input [7:0] start_num, end_num, output reg [7:0] results [0:15], output reg [4:0] count, output reg done);
  typedef enum logic [1:0] {IDLE, PROCESSING, CHECK_DIGITS, DONE} state_t;
  state_t current_state;
  reg [7:0] current_num;
  reg [3:0] hundreds, tens, units;

  wire valid = ((hundreds == 0) || (current_num % hundreds == 0)) &&
               ((tens == 0) || (current_num % tens == 0)) &&
               ((units == 0) || (current_num % units == 0));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count <= 0;
      done <= 0;
      current_num <= 0;
      hundreds <= 0;
      tens <= 0;
      units <= 0;
      foreach (results[i]) results[i] <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            current_num <= start_num;
            count <= 0;
            done <= 0;
            current_state <= PROCESSING;
          end
        end
        PROCESSING: begin
          hundreds <= (current_num / 100) % 10;
          tens <= (current_num / 10) % 10;
          units <= current_num % 10;
          current_state <= CHECK_DIGITS;
        end
        CHECK_DIGITS: begin
          if (valid && (count < 16)) begin
            results[count] <= current_num;
            count <= count + 1;
          end
          if (current_num == end_num) begin
            current_state <= DONE;
          end else begin
            current_num <= current_num + 1;
            current_state <= PROCESSING;
          end
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            current_state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule