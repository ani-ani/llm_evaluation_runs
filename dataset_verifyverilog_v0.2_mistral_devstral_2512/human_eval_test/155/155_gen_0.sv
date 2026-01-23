module even_odd_count (
  input clk,
  input rst_n,
  input start,
  input signed [31:0] num,
  output reg [4:0] even_count,
  output reg [4:0] odd_count,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [31:0] temp;
  reg [3:0] digit_count;
  reg [31:0] abs_num;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      even_count <= 0;
      odd_count <= 0;
      done <= 0;
      temp <= 0;
      digit_count <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          // Initialize counters and temp value
          even_count = 0;
          odd_count = 0;
          done = 0;
          digit_count = 0;
          // Handle negative numbers by taking absolute value
          abs_num = (num[31]) ? -num : num;
          temp = abs_num;
        end
      end
      PROCESSING: begin
        if (digit_count < 10) begin
          if (temp != 0) begin
            // Extract last digit
            reg [3:0] digit = temp % 10;
            // Check if even or odd
            if (digit[0] == 0) begin
              even_count = even_count + 1;
            end else begin
              odd_count = odd_count + 1;
            end
            // Remove last digit
            temp = temp / 10;
            digit_count = digit_count + 1;
          end else begin
            // Handle case when temp is 0 (special case for 0)
            if (digit_count == 0) begin
              even_count = 1;
              odd_count = 0;
            end
            next_state = DONE;
          end
        end else begin
          next_state = DONE;
        end
      end
      DONE: begin
        done = 1;
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule