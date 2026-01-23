module even_odd_palindrome (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] even_count,
  output reg [7:0] odd_count,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    CHECK_NEXT,
    COUNT_UP,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] current_number;
  reg is_palindrome;
  reg is_even;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_number <= 0;
      even_count <= 0;
      odd_count <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        next_state = CHECK_NEXT;
      end
      CHECK_NEXT: begin
        next_state = COUNT_UP;
      end
      COUNT_UP: begin
        if (current_number == n) next_state = DONE;
        else next_state = CHECK_NEXT;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_number <= 0;
      is_palindrome <= 0;
      is_even <= 0;
    end else begin
      case (current_state)
        INIT: begin
          current_number <= 1;
          even_count <= 0;
          odd_count <= 0;
          done <= 0;
        end
        CHECK_NEXT: begin
          // Check if current_number is a palindrome
          if (current_number < 10) begin
            is_palindrome = 1;
          end else if (current_number < 100) begin
            // Two-digit number
            is_palindrome = (current_number[7:4] == current_number[3:0]);
          end else begin
            // Three-digit number (100-255)
            is_palindrome = (current_number[7:6] == current_number[1:0]);
          end
          // Check if even
          is_even = (current_number[0] == 0);
        end
        COUNT_UP: begin
          if (is_palindrome) begin
            if (is_even) even_count <= even_count + 1;
            else odd_count <= odd_count + 1;
          end
          current_number <= current_number + 1;
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule