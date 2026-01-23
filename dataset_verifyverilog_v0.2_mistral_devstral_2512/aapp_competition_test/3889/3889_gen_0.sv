module doggo_standardization (
  input clk,
  input rst_n,
  input start,
  input [4:0] char_in,
  input char_valid,
  output reg result,
  output reg done
);

  parameter MAX_LEN = 16;
  parameter CHAR_WIDTH = 5;

  typedef enum logic [1:0] {
    IDLE,
    RECV,
    CHECK,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [4:0] char_count [0:25];
  reg [4:0] puppy_count;
  reg [3:0] cycle_counter;
  reg [3:0] input_counter;
  reg has_two_or_more;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      puppy_count <= 0;
      input_counter <= 0;
      cycle_counter <= 0;
      done <= 0;
      result <= 0;
      has_two_or_more <= 0;
      for (int i = 0; i < 26; i++) begin
        char_count[i] <= 0;
      end
    end else begin
      current_state <= next_state;
      if (current_state == RECV && char_valid) begin
        char_count[char_in] <= char_count[char_in] + 1;
        puppy_count <= puppy_count + 1;
        input_counter <= input_counter + 1;
      end
      if (current_state == CHECK && cycle_counter == 1) begin
        result <= (puppy_count == 1) || has_two_or_more;
        done <= 1;
      end
      if (current_state == CHECK && cycle_counter == 2) begin
        done <= 0;
      end
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = RECV;
          input_counter = 0;
          puppy_count = 0;
          has_two_or_more = 0;
          for (int i = 0; i < 26; i++) begin
            char_count[i] = 0;
          end
        end
      end
      RECV: begin
        if (input_counter == MAX_LEN - 1) begin
          next_state = CHECK;
          cycle_counter = 0;
        end
      end
      CHECK: begin
        if (cycle_counter == 0) begin
          for (int i = 0; i < 26; i++) begin
            if (char_count[i] >= 2) begin
              has_two_or_more = 1;
            end
          end
          cycle_counter = cycle_counter + 1;
        end else if (cycle_counter == 1) begin
          cycle_counter = cycle_counter + 1;
        end else if (cycle_counter == 2) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

endmodule